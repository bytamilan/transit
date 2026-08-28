package httpapi

import (
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
)

const supabaseAuthPathPrefix = "/auth/v1"

// NewAuthProxy exposes a GoTrue instance through the conventional Supabase
// /auth/v1 path. The API's CORS middleware wraps this handler, so browser
// clients do not need to call the direct GoTrue container.
func NewAuthProxy(target string) (http.Handler, error) {
	targetURL, err := url.Parse(target)
	if err != nil {
		return nil, err
	}

	proxy := httputil.NewSingleHostReverseProxy(targetURL)
	director := proxy.Director
	proxy.Director = func(r *http.Request) {
		director(r)
		r.URL.Path = strings.TrimPrefix(r.URL.Path, supabaseAuthPathPrefix)
		if r.URL.Path == "" {
			r.URL.Path = "/"
		}
		r.URL.RawPath = ""
	}
	proxy.ModifyResponse = func(response *http.Response) error {
		// GoTrue is normally deployed behind a Supabase gateway, which owns
		// CORS. Remove its direct-service CORS headers so the API middleware
		// can return one credential-safe policy to the browser.
		for _, header := range []string{
			"Access-Control-Allow-Credentials",
			"Access-Control-Allow-Headers",
			"Access-Control-Allow-Methods",
			"Access-Control-Allow-Origin",
			"Access-Control-Expose-Headers",
			"Access-Control-Max-Age",
		} {
			response.Header.Del(header)
		}
		return nil
	}
	return proxy, nil
}
