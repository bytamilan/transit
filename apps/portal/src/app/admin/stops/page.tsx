import Link from "next/link";
import { MapPin, DownloadCloud, ArrowRight } from "lucide-react";
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card";
import { buttonVariants } from "@/components/ui/button";

// NOTE: the admin API has no "list all stops" endpoint (stop data is managed
// per-route under Routes & Timetables, or imported in bulk here). This page is
// therefore the entry point to the OSM import tool rather than a stop list.
export default function StopsPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Stops</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Manage the agency&apos;s stop inventory. Stops attached to routes are edited per-route;
          bulk additions come from OpenStreetMap.
        </p>
      </div>

      <Card className="border-border/80 max-w-2xl">
        <CardHeader>
          <div className="flex items-center gap-2">
            <div className="flex size-9 items-center justify-center rounded-xl bg-primary/10 text-primary">
              <MapPin className="size-4" />
            </div>
            <div>
              <CardTitle className="text-base">Import Stops from OpenStreetMap</CardTitle>
              <CardDescription className="text-xs">
                Preview bus stops inside a map bounding box, edit them, then commit the selection.
              </CardDescription>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-between gap-3">
            <p className="text-xs text-muted-foreground max-w-sm">
              Draw an area on the map, review which stops are new and which already exist, adjust
              names and accessibility flags, and import only what you need.
            </p>
            <Link href="/admin/stops/import" className={buttonVariants({ size: "sm", className: "gap-1.5 shrink-0" })}>
              <DownloadCloud className="size-4" />
              <span>Open Import Tool</span>
              <ArrowRight className="size-3.5" />
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
