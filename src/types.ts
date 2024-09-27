// src/types.ts

export interface Stop {
    stop_id: string;
    stop_code: string;
    stop_name: string;
    stop_desc: string;
    stop_lat: string;
    stop_lon: string;
    zone_id: string;
    stop_url: string;
    location_type: string;
    parent_station: string;
    wheelchair_boarding: string;
  }
  
  export interface Trip {
    route_id: string;
    service_id: string;
    trip_id: string;
    trip_headsign: string;
    trip_short_name: string;
    direction_id: string;
    block_id: string;
    shape_id: string;
    wheelchair_accessible: string;
    bikes_allowed: string;
  }
  
  export interface StopTime {
    trip_id: string;
    arrival_time: string;
    departure_time: string;
    stop_id: string;
    stop_sequence: string;
    stop_headsign: string;
    pickup_type: string;
    drop_off_type: string;
    shape_dist_traveled: string;
    timepoint: string;
  }
  
  export interface BusStop extends Stop {
    distance: number; // in kilometers
    routesServiced: string[]; // List of trip_headsigns
  }
  