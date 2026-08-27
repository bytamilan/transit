export default function AdminOverviewPage() {
  return (
    <div className="max-w-2xl">
      <h1 className="text-2xl font-semibold">Overview</h1>
      <p className="mt-2 text-sm text-slate-600">
        Manage the fleet, drivers and duty roster for your agency. Every change here is
        recorded in the append-only audit log.
      </p>
      <div className="mt-6 grid grid-cols-2 gap-4">
        <a href="/admin/vehicles" className="rounded-lg border border-slate-200 bg-white p-4 hover:border-brand">
          <div className="font-medium">Vehicles</div>
          <div className="text-sm text-slate-500">Fleet, capacity, maintenance holds</div>
        </a>
        <a href="/admin/drivers" className="rounded-lg border border-slate-200 bg-white p-4 hover:border-brand">
          <div className="font-medium">Drivers</div>
          <div className="text-sm text-slate-500">Invites, depots, licence expiry</div>
        </a>
        <a href="/admin/routes" className="rounded-lg border border-slate-200 bg-white p-4 hover:border-brand">
          <div className="font-medium">Routes & timetables</div>
          <div className="text-sm text-slate-500">Stop sequences, service calendars</div>
        </a>
        <a href="/admin/roster" className="rounded-lg border border-slate-200 bg-white p-4 hover:border-brand">
          <div className="font-medium">Duty roster</div>
          <div className="text-sm text-slate-500">Assign blocks, resolve conflicts</div>
        </a>
      </div>
    </div>
  );
}
