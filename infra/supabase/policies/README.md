# RLS Policies

One file per table. Every policy scopes on the `agency_id` JWT claim — never a
request parameter. Roles come from the custom access token hook, never from
`user_metadata` (build brief §3.1, §8).
