package handlers

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"reflect"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/depots"
	"github.com/bytamilan/transit/services/api/internal/store/drivers"
	"github.com/bytamilan/transit/services/api/internal/store/vehicles"
)

// defaultLicenceWarningDays mirrors the dispatch package's default — the
// portal reads it from agency config in a later phase's admin settings
// screen; for now the same fixed default applies everywhere.
const defaultLicenceWarningDays = 30

var (
	errFleetNoAndRegistrationRequired = errors.New("fleet_no and registration are required")
	errNoInviterConfigured            = errors.New("driver invite is not configured on this server")
	errDriverIdentityRequired         = errors.New("email or phone is required to invite a driver")
	errEmptyCSV                       = errors.New("csv body has no rows")
	errInvalidUUID                    = errors.New("invalid uuid")
	errInvalidDate                    = errors.New("invalid date, expected YYYY-MM-DD")
	errInvalidWeekday                 = errors.New("invalid weekday, expected a lowercase day name")
)

// driverInviter creates a Supabase Auth user for a newly invited driver.
// Satisfied by *gotrue.Inviter; declared here so this package doesn't need
// to import gotrue directly and tests can supply a fake.
type driverInviter interface {
	InviteUser(ctx context.Context, email, phone string) (uuid.UUID, error)
}

// Fleet implements the vehicles, drivers and depots admin endpoints.
type Fleet struct {
	Vehicles *vehicles.Store
	Drivers  *drivers.Store
	Depots   *depots.Store
	Audit    *audit.Writer
	Inviter  driverInviter
}

const dateLayout = "2006-01-02"

// -- Depots ------------------------------------------------------------

type depotResponse struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type depotInput struct {
	Name string `json:"name"`
}

// ListDepots returns every depot for the caller's agency.
func (f *Fleet) ListDepots(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	list, err := f.Depots.List(r.Context(), actor.AgencyID)
	if err != nil {
		internalError(w, "list depots", err)
		return
	}
	out := make([]depotResponse, 0, len(list))
	for _, d := range list {
		out = append(out, depotResponse{ID: d.ID.String(), Name: d.Name})
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

// CreateDepot creates a depot.
func (f *Fleet) CreateDepot(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in depotInput
	if !decodeJSON(w, r, &in) {
		return
	}
	if in.Name == "" {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "name is required"})
		return
	}
	id, err := f.Depots.Upsert(r.Context(), actor.AgencyID, nil, in.Name)
	if err != nil {
		internalError(w, "create depot", err)
		return
	}
	f.audit(r, actor, "create", "depots", nil, map[string]any{"id": id, "name": in.Name})
	writeJSON(w, http.StatusCreated, depotResponse{ID: id.String(), Name: in.Name})
}

// -- Vehicles ------------------------------------------------------------

type vehicleResponse struct {
	ID              string         `json:"id"`
	DepotID         *string        `json:"depot_id,omitempty"`
	FleetNo         string         `json:"fleet_no"`
	Registration    string         `json:"registration"`
	CapacityClass   *string        `json:"capacity_class,omitempty"`
	Accessibility   map[string]any `json:"accessibility"`
	Propulsion      *string        `json:"propulsion,omitempty"`
	Status          string         `json:"status"`
	MaintenanceHold bool           `json:"maintenance_hold"`
}

type vehicleInput struct {
	FleetNo         string         `json:"fleet_no"`
	Registration    string         `json:"registration"`
	DepotID         *string        `json:"depot_id,omitempty"`
	CapacityClass   *string        `json:"capacity_class,omitempty"`
	Accessibility   map[string]any `json:"accessibility,omitempty"`
	Propulsion      *string        `json:"propulsion,omitempty"`
	Status          string         `json:"status,omitempty"`
	MaintenanceHold bool           `json:"maintenance_hold,omitempty"`
}

func toVehicleResponse(v vehicles.Vehicle) vehicleResponse {
	return vehicleResponse{
		ID: v.ID.String(), DepotID: uuidPtrString(v.DepotID), FleetNo: v.FleetNo,
		Registration: v.Registration, CapacityClass: v.CapacityClass, Accessibility: v.Accessibility,
		Propulsion: v.Propulsion, Status: v.Status, MaintenanceHold: v.MaintenanceHold,
	}
}

// ListVehicles returns vehicles for the caller's agency.
func (f *Fleet) ListVehicles(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	depotID, ok := parseOptionalUUIDQuery(w, r, "depot_id")
	if !ok {
		return
	}
	var status *string
	if v := r.URL.Query().Get("status"); v != "" {
		status = &v
	}
	limit, offset := parsePage(r)

	list, err := f.Vehicles.List(r.Context(), vehicles.ListParams{
		AgencyID: actor.AgencyID, DepotID: depotID, Status: status, Limit: limit, Offset: offset,
	})
	if err != nil {
		internalError(w, "list vehicles", err)
		return
	}
	total, err := f.Vehicles.Count(r.Context(), actor.AgencyID, depotID, status)
	if err != nil {
		internalError(w, "count vehicles", err)
		return
	}
	out := make([]vehicleResponse, 0, len(list))
	for _, v := range list {
		out = append(out, toVehicleResponse(v))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out, "total": total, "limit": limit, "offset": offset})
}

// UpsertVehicle creates or updates a vehicle by fleet_no.
func (f *Fleet) UpsertVehicle(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in vehicleInput
	if !decodeJSON(w, r, &in) {
		return
	}
	id, code, err := f.upsertVehicle(r.Context(), actor, in)
	if err != nil {
		writeJSON(w, code, errorResponse{Error: err.Error()})
		return
	}
	v, err := f.Vehicles.Get(r.Context(), actor.AgencyID, id)
	if err != nil || v == nil {
		internalError(w, "reload vehicle", err)
		return
	}
	writeJSON(w, http.StatusOK, toVehicleResponse(*v))
}

func (f *Fleet) upsertVehicle(ctx context.Context, actor auth.Actor, in vehicleInput) (uuid.UUID, int, error) {
	if in.FleetNo == "" || in.Registration == "" {
		return uuid.Nil, http.StatusBadRequest, errFleetNoAndRegistrationRequired
	}
	depotID, err := parseOptionalUUID(in.DepotID)
	if err != nil {
		return uuid.Nil, http.StatusBadRequest, err
	}
	id, err := f.Vehicles.Upsert(ctx, vehicles.UpsertParams{
		AgencyID: actor.AgencyID, FleetNo: in.FleetNo, Registration: in.Registration, DepotID: depotID,
		CapacityClass: in.CapacityClass, Accessibility: in.Accessibility, Propulsion: in.Propulsion,
		Status: in.Status, MaintenanceHold: in.MaintenanceHold,
	})
	if err != nil {
		return uuid.Nil, http.StatusInternalServerError, err
	}
	f.audit(nil, actor, "upsert", "vehicles", nil, map[string]any{"fleet_no": in.FleetNo})
	return id, http.StatusOK, nil
}

// GetVehicle returns a single vehicle.
func (f *Fleet) GetVehicle(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetRead) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	v, err := f.Vehicles.Get(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "get vehicle", err)
		return
	}
	if v == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "vehicle not found"})
		return
	}
	writeJSON(w, http.StatusOK, toVehicleResponse(*v))
}

// DeleteVehicle removes a vehicle.
func (f *Fleet) DeleteVehicle(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	if err := f.Vehicles.Delete(r.Context(), actor.AgencyID, id); err != nil {
		internalError(w, "delete vehicle", err)
		return
	}
	f.audit(r, actor, "delete", "vehicles", map[string]any{"id": id}, nil)
	w.WriteHeader(http.StatusNoContent)
}

// ImportVehicles bulk-upserts vehicles from a CSV body with header row:
// fleet_no,registration,depot_id,capacity_class,propulsion,status,maintenance_hold
func (f *Fleet) ImportVehicles(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	rows, header, err := readCSV(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: err.Error()})
		return
	}
	col := columnIndex(header)

	var report []importRowResult
	for i, row := range rows {
		in := vehicleInput{
			FleetNo:       col.get(row, "fleet_no"),
			Registration:  col.get(row, "registration"),
			CapacityClass: nonEmptyPtr(col.get(row, "capacity_class")),
			Propulsion:    nonEmptyPtr(col.get(row, "propulsion")),
			Status:        col.get(row, "status"),
		}
		if v := col.get(row, "depot_id"); v != "" {
			in.DepotID = &v
		}
		if v := col.get(row, "maintenance_hold"); v != "" {
			in.MaintenanceHold, _ = strconv.ParseBool(v)
		}

		_, _, err := f.upsertVehicle(r.Context(), actor, in)
		report = append(report, rowResult(i+2, in.FleetNo, err))
	}
	writeJSON(w, http.StatusOK, map[string]any{"rows": report})
}

// -- Drivers ------------------------------------------------------------

type driverResponse struct {
	UserID           string  `json:"user_id"`
	DepotID          *string `json:"depot_id,omitempty"`
	DisplayName      *string `json:"display_name,omitempty"`
	InviteEmail      *string `json:"invite_email,omitempty"`
	InvitePhone      *string `json:"invite_phone,omitempty"`
	LicenceExpiresOn *string `json:"licence_expires_on,omitempty"`
	Status           string  `json:"status"`
	LicenceWarning   bool    `json:"licence_warning"`
	LicenceExpired   bool    `json:"licence_expired"`
}

type driverInput struct {
	UserID           *string `json:"user_id,omitempty"`
	Email            string  `json:"email,omitempty"`
	Phone            string  `json:"phone,omitempty"`
	DisplayName      *string `json:"display_name,omitempty"`
	DepotID          *string `json:"depot_id,omitempty"`
	LicenceNumber    *string `json:"licence_number,omitempty"`
	LicenceExpiresOn *string `json:"licence_expires_on,omitempty"`
	Status           string  `json:"status,omitempty"`
}

func toDriverResponse(d drivers.Driver, warningDays int) driverResponse {
	now := time.Now()
	resp := driverResponse{
		UserID: d.UserID.String(), DepotID: uuidPtrString(d.DepotID), DisplayName: d.DisplayName,
		InviteEmail: d.InviteEmail, InvitePhone: d.InvitePhone, Status: d.Status,
		LicenceWarning: d.LicenceWarning(now, warningDays),
	}
	if d.LicenceExpiresOn != nil {
		s := d.LicenceExpiresOn.Format(dateLayout)
		resp.LicenceExpiresOn = &s
		resp.LicenceExpired = d.LicenceExpiresOn.Before(now)
	}
	return resp
}

// ListDrivers returns driver profiles for the caller's agency.
func (f *Fleet) ListDrivers(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverRead) {
		return
	}
	depotID, ok := parseOptionalUUIDQuery(w, r, "depot_id")
	if !ok {
		return
	}
	var status *string
	if v := r.URL.Query().Get("status"); v != "" {
		status = &v
	}
	limit, offset := parsePage(r)

	list, err := f.Drivers.List(r.Context(), drivers.ListParams{
		AgencyID: actor.AgencyID, DepotID: depotID, Status: status, Limit: limit, Offset: offset,
	})
	if err != nil {
		internalError(w, "list drivers", err)
		return
	}
	total, err := f.Drivers.Count(r.Context(), actor.AgencyID, depotID, status)
	if err != nil {
		internalError(w, "count drivers", err)
		return
	}
	out := make([]driverResponse, 0, len(list))
	for _, d := range list {
		out = append(out, toDriverResponse(d, defaultLicenceWarningDays))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out, "total": total, "limit": limit, "offset": offset})
}

// InviteDriver creates (or attaches to an existing) auth user and their
// driver profile, and grants the driver role.
func (f *Fleet) InviteDriver(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverWrite) {
		return
	}
	var in driverInput
	if !decodeJSON(w, r, &in) {
		return
	}
	id, code, err := f.upsertDriver(r.Context(), actor, in)
	if err != nil {
		writeJSON(w, code, errorResponse{Error: err.Error()})
		return
	}
	d, err := f.Drivers.Get(r.Context(), actor.AgencyID, id)
	if err != nil || d == nil {
		internalError(w, "reload driver", err)
		return
	}
	writeJSON(w, http.StatusOK, toDriverResponse(*d, defaultLicenceWarningDays))
}

func (f *Fleet) upsertDriver(ctx context.Context, actor auth.Actor, in driverInput) (uuid.UUID, int, error) {
	userID, err := parseOptionalUUID(in.UserID)
	if err != nil {
		return uuid.Nil, http.StatusBadRequest, err
	}
	if userID == nil {
		if isNilDriverInviter(f.Inviter) {
			return uuid.Nil, http.StatusBadRequest, errNoInviterConfigured
		}
		if in.Email == "" && in.Phone == "" {
			return uuid.Nil, http.StatusBadRequest, errDriverIdentityRequired
		}
		newID, err := f.Inviter.InviteUser(ctx, in.Email, in.Phone)
		if err != nil {
			return uuid.Nil, http.StatusBadGateway, err
		}
		userID = &newID
	}

	depotID, err := parseOptionalUUID(in.DepotID)
	if err != nil {
		return uuid.Nil, http.StatusBadRequest, err
	}
	expiresOn, err := parseOptionalDate(in.LicenceExpiresOn)
	if err != nil {
		return uuid.Nil, http.StatusBadRequest, err
	}

	var emailPtr, phonePtr *string
	if in.Email != "" {
		emailPtr = &in.Email
	}
	if in.Phone != "" {
		phonePtr = &in.Phone
	}

	id, err := f.Drivers.Upsert(ctx, drivers.UpsertParams{
		AgencyID: actor.AgencyID, UserID: *userID, DepotID: depotID, DisplayName: in.DisplayName,
		InviteEmail: emailPtr, InvitePhone: phonePtr, LicenceNumber: in.LicenceNumber,
		LicenceExpiresOn: expiresOn, Status: in.Status,
	})
	if err != nil {
		return uuid.Nil, http.StatusInternalServerError, err
	}
	f.audit(nil, actor, "upsert", "driver_profiles", nil, map[string]any{"user_id": id})
	return id, http.StatusOK, nil
}

// Interfaces can contain a typed nil pointer. Treat those values as an
// unconfigured inviter too, otherwise calling InviteUser would panic and the
// HTTP client would observe an empty response.
func isNilDriverInviter(inviter driverInviter) bool {
	if inviter == nil {
		return true
	}
	v := reflect.ValueOf(inviter)
	switch v.Kind() {
	case reflect.Chan, reflect.Func, reflect.Interface, reflect.Map, reflect.Ptr, reflect.Slice:
		return v.IsNil()
	default:
		return false
	}
}

// GetDriver returns a single driver profile.
func (f *Fleet) GetDriver(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverRead) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	d, err := f.Drivers.Get(r.Context(), actor.AgencyID, id)
	if err != nil {
		internalError(w, "get driver", err)
		return
	}
	if d == nil {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "driver not found"})
		return
	}
	writeJSON(w, http.StatusOK, toDriverResponse(*d, defaultLicenceWarningDays))
}

// SetDriverStatus suspends or reactivates a driver.
func (f *Fleet) SetDriverStatus(w http.ResponseWriter, r *http.Request, status string) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverWrite) {
		return
	}
	id, ok := parseURLUUID(w, r, "id")
	if !ok {
		return
	}
	if err := f.Drivers.SetStatus(r.Context(), actor.AgencyID, id, status); err != nil {
		internalError(w, "set driver status", err)
		return
	}
	f.audit(r, actor, "update", "driver_profiles", nil, map[string]any{"user_id": id, "status": status})
	w.WriteHeader(http.StatusNoContent)
}

// SuspendDriver marks a driver suspended.
func (f *Fleet) SuspendDriver(w http.ResponseWriter, r *http.Request) {
	f.SetDriverStatus(w, r, "suspended")
}

// ReactivateDriver marks a driver active.
func (f *Fleet) ReactivateDriver(w http.ResponseWriter, r *http.Request) {
	f.SetDriverStatus(w, r, "active")
}

// ImportDrivers bulk-invites/upserts drivers from a CSV body with header row:
// email,phone,display_name,depot_id,licence_number,licence_expires_on
func (f *Fleet) ImportDrivers(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermDriverWrite) {
		return
	}
	rows, header, err := readCSV(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: err.Error()})
		return
	}
	col := columnIndex(header)

	var report []importRowResult
	for i, row := range rows {
		in := driverInput{
			Email:            col.get(row, "email"),
			Phone:            col.get(row, "phone"),
			DisplayName:      nonEmptyPtr(col.get(row, "display_name")),
			LicenceNumber:    nonEmptyPtr(col.get(row, "licence_number")),
			LicenceExpiresOn: nonEmptyPtr(col.get(row, "licence_expires_on")),
		}
		if v := col.get(row, "depot_id"); v != "" {
			in.DepotID = &v
		}
		label := in.Email
		if label == "" {
			label = in.Phone
		}
		_, _, err := f.upsertDriver(r.Context(), actor, in)
		report = append(report, rowResult(i+2, label, err))
	}
	writeJSON(w, http.StatusOK, map[string]any{"rows": report})
}

// -- shared helpers ------------------------------------------------------

type importRowResult struct {
	Row    int    `json:"row"`
	Key    string `json:"key"`
	Status string `json:"status"`
	Error  string `json:"error,omitempty"`
}

func rowResult(row int, key string, err error) importRowResult {
	if err != nil {
		return importRowResult{Row: row, Key: key, Status: "error", Error: err.Error()}
	}
	return importRowResult{Row: row, Key: key, Status: "ok"}
}

type columnMap map[string]int

func columnIndex(header []string) columnMap {
	m := make(columnMap, len(header))
	for i, h := range header {
		m[h] = i
	}
	return m
}

func (c columnMap) get(row []string, name string) string {
	i, ok := c[name]
	if !ok || i >= len(row) {
		return ""
	}
	return row[i]
}

// readCSV parses a text/csv request body into a header row and data rows.
// One bad row does not abort the whole import — validation errors surface
// per-row in the returned report instead.
func readCSV(r *http.Request) (rows [][]string, header []string, err error) {
	defer r.Body.Close()
	cr := csv.NewReader(io.LimitReader(r.Body, 5<<20)) // 5MB cap
	cr.TrimLeadingSpace = true
	all, err := cr.ReadAll()
	if err != nil {
		return nil, nil, err
	}
	if len(all) == 0 {
		return nil, nil, errEmptyCSV
	}
	return all[1:], all[0], nil
}

func decodeJSON(w http.ResponseWriter, r *http.Request, v any) bool {
	defer r.Body.Close()
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid JSON body: " + err.Error()})
		return false
	}
	return true
}

func requirePermission(w http.ResponseWriter, actor auth.Actor, perm rbac.Permission) bool {
	if actor.Anonymous() {
		writeJSON(w, http.StatusUnauthorized, errorResponse{Error: "unauthenticated"})
		return false
	}
	if !rbac.ActorHas(actor, perm) {
		writeJSON(w, http.StatusForbidden, errorResponse{Error: "forbidden"})
		return false
	}
	return true
}

func internalError(w http.ResponseWriter, msg string, err error) {
	slog.Error(msg, "err", err)
	writeJSON(w, http.StatusInternalServerError, errorResponse{Error: "internal error"})
}

func (f *Fleet) audit(r *http.Request, actor auth.Actor, action, entity string, before, after map[string]any) {
	if f.Audit == nil {
		return
	}
	var ip = actor.IP
	entry := audit.Entry{AgencyID: actor.AgencyID, ActorID: actor.UserID, Action: action, Entity: entity, Before: before, After: after, IP: ip}
	if err := f.Audit.Write(context.Background(), entry); err != nil {
		slog.Error("fleet: failed to write audit log entry", "action", action, "entity", entity, "err", err)
	}
}

func parseURLUUID(w http.ResponseWriter, r *http.Request, param string) (uuid.UUID, bool) {
	id, err := uuid.Parse(chi.URLParam(r, param))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid " + param})
		return uuid.Nil, false
	}
	return id, true
}

func parseOptionalUUIDQuery(w http.ResponseWriter, r *http.Request, param string) (*uuid.UUID, bool) {
	v := r.URL.Query().Get(param)
	if v == "" {
		return nil, true
	}
	id, err := uuid.Parse(v)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Error: "invalid " + param})
		return nil, false
	}
	return &id, true
}

func parseOptionalUUID(s *string) (*uuid.UUID, error) {
	if s == nil || *s == "" {
		return nil, nil
	}
	id, err := uuid.Parse(*s)
	if err != nil {
		return nil, errInvalidUUID
	}
	return &id, nil
}

func parseOptionalDate(s *string) (*time.Time, error) {
	if s == nil || *s == "" {
		return nil, nil
	}
	t, err := time.Parse(dateLayout, *s)
	if err != nil {
		return nil, errInvalidDate
	}
	return &t, nil
}

func nonEmptyPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func uuidPtrString(id *uuid.UUID) *string {
	if id == nil {
		return nil
	}
	s := id.String()
	return &s
}

func parsePage(r *http.Request) (limit, offset int) {
	limit = 50
	offset = 0
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 500 {
			limit = n
		}
	}
	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = n
		}
	}
	return limit, offset
}
