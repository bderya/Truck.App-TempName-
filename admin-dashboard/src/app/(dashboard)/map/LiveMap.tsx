"use client";

import { createClient } from "@/lib/supabase/client";
import "leaflet/dist/leaflet.css";
import type { Booking, TowTruck } from "@/types/database";
import L from "leaflet";
import React, { useCallback, useEffect, useRef, useState } from "react";
import { MapContainer, Marker, Popup, TileLayer, useMap } from "react-leaflet";

const ACTIVE_STATUSES = ["accepted", "on_the_way", "picked_up"];

const driverIcon = L.divIcon({
  className: "driver-marker",
  html: `<div style="width:24px;height:24px;border-radius:50%;background:#3b82f6;border:2px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12],
});

const pickupIcon = L.divIcon({
  className: "pickup-marker",
  html: `<div style="width:20px;height:20px;border-radius:4px;background:#22c55e;border:2px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10],
});

const destinationIcon = L.divIcon({
  className: "destination-marker",
  html: `<div style="width:20px;height:20px;border-radius:4px;background:#ef4444;border:2px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.3)"></div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10],
});

function FitBounds({ trucks, bookings }: { trucks: TowTruck[]; bookings: Booking[] }) {
  const map = useMap();
  const fitted = useRef(false);
  useEffect(() => {
    if (fitted.current) return;
    const points: [number, number][] = [];
    trucks.forEach((t) => {
      if (t.current_latitude && t.current_longitude) points.push([t.current_latitude, t.current_longitude]);
    });
    bookings.forEach((b) => {
      points.push([b.pickup_lat, b.pickup_lng]);
      if (b.destination_lat != null && b.destination_lng != null)
        points.push([b.destination_lat, b.destination_lng]);
    });
    if (points.length === 0) return;
    fitted.current = true;
    map.fitBounds(points as [number, number][], { padding: [40, 40], maxZoom: 12 });
  }, [map, trucks, bookings]);
  return null;
}

export default function LiveMap() {
  const [trucks, setTrucks] = useState<TowTruck[]>([]);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const supabase = createClient();
  const loaded = useRef(false);

  const fetchTrucks = useCallback(async () => {
    const { data } = await supabase
      .from("tow_trucks")
      .select("*")
      .not("current_latitude", "is", null)
      .not("current_longitude", "is", null);
    if (data) setTrucks(data as TowTruck[]);
  }, [supabase]);

  const fetchActiveBookings = useCallback(async () => {
    const { data } = await supabase
      .from("bookings")
      .select("*")
      .in("status", ACTIVE_STATUSES);
    if (data) setBookings(data as Booking[]);
  }, [supabase]);

  useEffect(() => {
    if (loaded.current) return;
    loaded.current = true;
    fetchTrucks();
    fetchActiveBookings();

    const channel = supabase
      .channel("admin-map")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "tow_trucks" },
        () => fetchTrucks()
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "bookings" },
        () => fetchActiveBookings()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [supabase, fetchTrucks, fetchActiveBookings]);

  const defaultCenter: [number, number] = [41.0082, 28.9784];

  return (
    <div className="h-[calc(100vh-6rem)] w-full rounded-xl overflow-hidden border border-slate-700">
      <MapContainer
        center={defaultCenter}
        zoom={10}
        className="h-full w-full"
        scrollWheelZoom
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <FitBounds trucks={trucks} bookings={bookings} />
        {trucks.map((t) => (
          <Marker
            key={t.id}
            position={[t.current_latitude, t.current_longitude]}
            icon={driverIcon}
          >
            <Popup>
              <span className="font-medium">{t.plate_number}</span>
              <br />
              <span className="text-slate-500">{t.is_available ? "Müsait" : "Meşgul"}</span>
            </Popup>
          </Marker>
        ))}
        {bookings.map((b) => (
          <React.Fragment key={b.id}>
            <Marker
              position={[b.pickup_lat, b.pickup_lng]}
              icon={pickupIcon}
            >
              <Popup>
                <span className="font-medium">Alış #{b.id}</span>
                <br />
                {b.pickup_address}
                <br />
                <span className="text-slate-500">{b.status}</span>
              </Popup>
            </Marker>
            {b.destination_lat != null && b.destination_lng != null && (
              <Marker
                position={[b.destination_lat, b.destination_lng]}
                icon={destinationIcon}
              >
                <Popup>
                  <span className="font-medium">Varış #{b.id}</span>
                  <br />
                  {b.destination_address}
                </Popup>
              </Marker>
            )}
          </React.Fragment>
        ))}
      </MapContainer>
    </div>
  );
}
