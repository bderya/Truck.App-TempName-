export type UserType = "client" | "driver";
export type VerificationStatus = "pending" | "approved" | "rejected";
export type BookingStatus =
  | "pending"
  | "assigned"
  | "accepted"
  | "on_the_way"
  | "picked_up"
  | "completed"
  | "cancelled";

export interface User {
  id: number;
  phone_number: string;
  full_name: string;
  user_type: UserType;
  avatar_url: string | null;
  is_verified: boolean;
  status: VerificationStatus;
  license_image_url: string | null;
  criminal_record_url: string | null;
  plate_image_url?: string | null;
  national_id?: string | null;
  selfie_with_license_url?: string | null;
  created_at: string;
  updated_at: string;
}

export interface TowTruck {
  id: number;
  driver_id: number;
  plate_number: string;
  truck_type: string;
  current_latitude: number;
  current_longitude: number;
  is_available: boolean;
  plate_image_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface Booking {
  id: number;
  client_id: number;
  driver_id: number | null;
  pickup_address: string;
  destination_address: string;
  pickup_lat: number;
  pickup_lng: number;
  destination_lat?: number | null;
  destination_lng?: number | null;
  price: number | null;
  vehicle_type_requested: string;
  status: BookingStatus;
  created_at: string;
  updated_at: string;
  ended_at?: string | null;
}
