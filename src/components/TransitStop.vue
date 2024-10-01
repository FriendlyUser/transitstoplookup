<script>
export default {
  data() {
    return {
      city: '',
      street: '',
      radius: 800, // Default radius in meters
      busStops: [],
      error: null,
      stopsData: null,
      stopTimesData: null,
      tripsData: null,
      routesData: null,
      stopTimesByStopId: {},
      tripsByTripId: {},
      routesByRouteId: {},
      routeFrequencyTableData: [],
      calendarData: null,
      calendarDatesData: null,
      serviceIdToDays: {}, // Maps service_id to service days
    };
  },
  mounted() {
    Promise.all([
      fetch('/transitstoplookup/stops.txt').then((response) => response.text()),
      fetch('/transitstoplookup/stop_times.txt').then((response) => response.text()),
      fetch('/transitstoplookup/trips.txt').then((response) => response.text()),
      fetch('/transitstoplookup/routes.txt').then((response) => response.text()),
      fetch('/transitstoplookup/calendar.txt').then((response) => response.text()),
      fetch('/transitstoplookup/calendar_dates.txt').then((response) => response.text()),
    ])
    .then(([stopsData, stopTimesData, tripsData, routesData, calendarData, calendarDatesData]) => {
        this.parseCalendarData(calendarData);
        this.parseCalendarDatesData(calendarDatesData);
        this.parseStopsData(stopsData);
        this.parseStopTimesData(stopTimesData);
        this.parseTripsData(tripsData);
        this.parseRoutesData(routesData);
      })
      .catch((error) => {
        this.error = 'Error loading GTFS data';
        console.error(error);
      });
  },
  methods: {
    // Parse stops.txt data
    parseStopsData(data) {
      const lines = data.trim().split('\n');
      const keys = lines[0].split(','); // Extract header row
      this.stopsData = lines.slice(1).map((line) => {
        const values = line.split(',');
        const stop = {};
        keys.forEach((key, index) => {
          stop[key] = values[index];
        });
        return stop;
      });
    },

    // Parse stop_times.txt data
    parseStopTimesData(data) {
      const lines = data.trim().split('\n');
      const keys = lines[0].split(','); // Extract header row
      this.stopTimesData = lines.slice(1).map((line) => {
        const values = line.split(',');
        const stopTime = {};
        keys.forEach((key, index) => {
          stopTime[key] = values[index];
        });
        return stopTime;
      });

      // Build index by stop_id
      this.stopTimesData.forEach((stopTime) => {
        const stop_id = stopTime.stop_id;
        if (!this.stopTimesByStopId[stop_id]) {
          this.stopTimesByStopId[stop_id] = [];
        }
        this.stopTimesByStopId[stop_id].push(stopTime);
      });
    },

    // Parse trips.txt data
    parseTripsData(data) {
      const lines = data.trim().split('\n');
      const keys = lines[0].split(','); // Extract header row
      this.tripsData = lines.slice(1).map((line) => {
        const values = line.split(',');
        const trip = {};
        keys.forEach((key, index) => {
          trip[key] = values[index];
        });
        return trip;
      });

      // Build index by trip_id and include service days
      this.tripsData.forEach((trip) => {
        const serviceDays = this.serviceIdToDays[trip.service_id];
        this.tripsByTripId[trip.trip_id] = {
          ...trip,
          serviceDays,
        };
      });
    },

    // Parse routes.txt data
    parseRoutesData(data) {
      const lines = data.trim().split('\n');
      const keys = lines[0].split(','); // Extract header row
      this.routesData = lines.slice(1).map((line) => {
        const values = line.split(',');
        const route = {};
        keys.forEach((key, index) => {
          route[key] = values[index];
        });
        return route;
      });

      // Build index by route_id
      this.routesData.forEach((route) => {
        this.routesByRouteId[route.route_id] = route;
      });
    },

    parseCalendarData(data) {
      const lines = data.trim().split('\n');
      const keys = lines[0].split(','); // Extract header row
      this.calendarData = lines.slice(1).map((line) => {
        const values = line.split(',');
        const calendarEntry = {};
        keys.forEach((key, index) => {
          calendarEntry[key] = values[index];
        });
        return calendarEntry;
      });

      // Map service_id to service days
      this.calendarData.forEach((entry) => {
        const service_id = entry.service_id;
        const days = {
          monday: entry.monday === '1',
          tuesday: entry.tuesday === '1',
          wednesday: entry.wednesday === '1',
          thursday: entry.thursday === '1',
          friday: entry.friday === '1',
          saturday: entry.saturday === '1',
          sunday: entry.sunday === '1',
          start_date: entry.start_date,
          end_date: entry.end_date,
        };
        this.serviceIdToDays[service_id] = days;
      });
    },

    // Parse calendar_dates.txt data
    parseCalendarDatesData(data) {
      const lines = data.trim().split('\n');
      const keys = lines[0].split(','); // Extract header row
      this.calendarDatesData = lines.slice(1).map((line) => {
        const values = line.split(',');
        const calendarDateEntry = {};
        keys.forEach((key, index) => {
          calendarDateEntry[key] = values[index];
        });
        return calendarDateEntry;
      });

      // Apply exceptions to service days
      this.calendarDatesData.forEach((entry) => {
        const service_id = entry.service_id;
        const date = entry.date;
        const exception_type = entry.exception_type; // 1=Added service, 2=Removed service

        // For simplicity, we'll ignore specific dates in this example
        // You can implement date checks here if needed
      });
    },

    // Perform search based on city and street
    searchLocation() {
      this.error = null;
      this.busStops = [];
      this.routeFrequencyTableData = [];

      if (!this.city || !this.street) {
        this.error = 'Please enter both city and street.';
        return;
      }

      const apiUrl = `https://nominatim.openstreetmap.org/search?city=${encodeURIComponent(
        this.city
      )}&street=${encodeURIComponent(this.street)}&format=json`;

      fetch(apiUrl)
        .then((response) => response.json())
        .then((data) => {
          if (data.length > 0) {
            const { lat, lon } = data[0]; // Extract lat and lon from API response
            this.findNearbyStops(parseFloat(lat), parseFloat(lon));
          } else {
            this.error = 'Location not found.';
          }
        })
        .catch((error) => {
          this.error = 'Error fetching location data.';
          console.error(error);
        });
    },

    // Calculate distance between two points using the Haversine formula
    haversineDistance(lat1, lon1, lat2, lon2) {
      const toRad = (val) => (val * Math.PI) / 180;
      const R = 6371; // Earth's radius in km
      const dLat = toRad(lat2 - lat1);
      const dLon = toRad(lon2 - lon1);
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRad(lat1)) *
          Math.cos(toRad(lat2)) *
          Math.sin(dLon / 2) *
          Math.sin(dLon / 2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      return R * c; // Distance in km
    },

    // Find stops within a certain radius (meters)
    findNearbyStops(lat, lon) {
      const radiusInKm = this.radius / 1000; // Convert meters to kilometers
      this.busStops = this.stopsData
        .map((stop) => {
          const distance = this.haversineDistance(
            lat,
            lon,
            parseFloat(stop.stop_lat),
            parseFloat(stop.stop_lon)
          );
          return { ...stop, distance };
        })
        .filter((stop) => stop.distance <= radiusInKm)
        .sort((a, b) => a.distance - b.distance); // Optional: sort by distance

      // After finding nearby stops, compute route frequencies
      this.computeRouteFrequencies();
    },

    // Compute route frequencies per route at each stop
    computeRouteFrequencies() {
      this.routeFrequencyTableData = []; // Clear previous data
      const timePeriods = [
        { name: 'AM Peak', start: 360, end: 540, days: ['weekday'] }, // 6:00 to 9:00
        { name: 'Mid-day', start: 540, end: 900, days: ['weekday'] }, // 9:00 to 15:00
        { name: 'PM Peak', start: 900, end: 1140, days: ['weekday'] }, // 15:00 to 19:00
        { name: 'Evening', start: 1140, end: 1440, days: ['weekday'] }, // 19:00 to 24:00
        { name: 'Weekend', start: 0, end: 1440, days: ['weekend'] }, // All day
      ];
      // For each nearby stop
      this.busStops.forEach((stop) => {
        const stop_id = stop.stop_id;
        const stop_name = stop.stop_name;
        const stop_times = this.stopTimesByStopId[stop_id] || [];

        // Group stop_times by route_id
        const routeTimes = {};

        stop_times.forEach((stop_time) => {
          const trip_id = stop_time.trip_id;
          const arrival_time = stop_time.arrival_time;
          const tripData = this.tripsByTripId[trip_id];
          if (tripData) {
            const route_id = tripData.route_id;
            const serviceDays = tripData.serviceDays;

            if (!routeTimes[route_id]) {
              routeTimes[route_id] = {
                route: this.routesByRouteId[route_id],
                arrival_times: [],
                serviceDays: {},
              };
            }
            routeTimes[route_id].arrival_times.push({
              time: arrival_time,
              serviceDays: serviceDays,
            });
          }
        });

        // For each route at this stop, compute headway and service span
        Object.keys(routeTimes).forEach((route_id) => {
          const routeData = routeTimes[route_id];

          // Convert arrival times to minutes since midnight and sort them
          const timesInMinutes = routeData.arrival_times.map((entry) => ({
            timeInMinutes: this.timeToMinutes(entry.time),
            serviceDays: entry.serviceDays,
          }));

          // Compute service span and headways for each time period
          const periodHeadways = {};

          timePeriods.forEach((period) => {
            const periodTimes = timesInMinutes.filter((entry) => {
              const time = entry.timeInMinutes;
              const isInPeriod = time >= period.start && time < period.end;
              const runsOnPeriodDay = period.days.includes(
                this.getDayType(entry.serviceDays)
              );
              return isInPeriod && runsOnPeriodDay;
            });

            const sortedTimes = periodTimes
              .map((entry) => entry.timeInMinutes)
              .sort((a, b) => a - b);

            // Compute intervals between consecutive arrivals
            const intervals = [];
            for (let i = 1; i < sortedTimes.length; i++) {
              const interval = sortedTimes[i] - sortedTimes[i - 1];
              // Ignore intervals longer than 120 minutes to filter out gaps
              if (interval <= 120) {
                intervals.push(interval);
              }
            }

            // Compute average headway
            let avgHeadway = 'N/A';
            if (intervals.length > 0) {
              const totalInterval = intervals.reduce((a, b) => a + b, 0);
              avgHeadway = (totalInterval / intervals.length).toFixed(1);
            }

            periodHeadways[period.name] = avgHeadway;
          });

          // Compute service span start and end times for weekdays
          const weekdayTimes = timesInMinutes.filter((entry) =>
            this.isWeekday(entry.serviceDays)
          ).map((entry) => entry.timeInMinutes);

          const serviceStart =
            weekdayTimes.length > 0
              ? this.minutesToTime(Math.min(...weekdayTimes))
              : 'N/A';
          const serviceEnd =
            weekdayTimes.length > 0
              ? this.minutesToTime(Math.max(...weekdayTimes))
              : 'N/A';

          // Prepare table entry
          const tableEntry = {
            route: routeData.route.route_short_name || 'N/A',
            direction: routeData.route.route_long_name || 'N/A',
            stop: stop_name,
            weekdayServiceStart: serviceStart,
            weekdayServiceEnd: serviceEnd,
            amHeadway: periodHeadways['AM Peak'],
            midDayHeadway: periodHeadways['Mid-day'],
            pmHeadway: periodHeadways['PM Peak'],
            eveningHeadway: periodHeadways['Evening'],
            weekendHeadway: periodHeadways['Weekend'],
          };

          this.routeFrequencyTableData.push(tableEntry);
        });
      });
    },

  // Helper function to determine if the service runs on weekdays
  isWeekday(serviceDays) {
    return (
      serviceDays.monday ||
      serviceDays.tuesday ||
      serviceDays.wednesday ||
      serviceDays.thursday ||
      serviceDays.friday
    );
  },

  // Helper function to determine the day type
  getDayType(serviceDays) {
    if (
      serviceDays.saturday ||
      serviceDays.sunday
    ) {
      return 'weekend';
    } else if (
      serviceDays.monday ||
      serviceDays.tuesday ||
      serviceDays.wednesday ||
      serviceDays.thursday ||
      serviceDays.friday
    ) {
      return 'weekday';
    }
    return 'unknown';
  },

    // Convert HH:MM:SS to minutes since midnight
    timeToMinutes(timeStr) {
      const [hoursStr, minutesStr, secondsStr] = timeStr.split(':');
      const hours = parseInt(hoursStr, 10);
      const minutes = parseInt(minutesStr, 10);
      const seconds = parseInt(secondsStr, 10);
      return hours * 60 + minutes + seconds / 60;
    },

    // Convert minutes since midnight to HH:MM format
    minutesToTime(minutes) {
      const hrs = Math.floor(minutes / 60);
      const mins = Math.floor(minutes % 60);
      return `${hrs.toString().padStart(2, '0')}:${mins
        .toString()
        .padStart(2, '0')}`;
    },

    // Copy table HTML to clipboard
    copyTableToClipboard() {
      const tableElement = this.$refs.busStopsTable;
      const selection = window.getSelection();
      const range = document.createRange();

      range.selectNodeContents(tableElement);
      selection?.removeAllRanges();
      selection?.addRange(range);

      try {
        const successful = document.execCommand('copy');
        if (successful) {
          alert('Table copied to clipboard!');
        } else {
          alert('Failed to copy table.');
        }
      } catch (err) {
        console.error('Error copying table:', err);
        alert('Error copying table.');
      }

      selection?.removeAllRanges();
    },
  },
};

</script>

<template>
  <div class="p-6 max-w-7xl mx-auto bg-white shadow-md rounded-md">
    <!-- ... existing form and bus stops table ... -->
    <h1 class="text-3xl font-semibold mb-6 text-center">Find Nearby Bus Stops</h1>
    <form @submit.prevent="searchLocation">
      <div class="grid grid-cols-1 gap-4 mb-4">
        <div>
          <label for="city" class="block text-gray-700 font-medium mb-2">City</label>
          <input
            v-model="city"
            id="city"
            type="text"
            class="w-full p-3 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Enter city"
          />
        </div>
        <div>
          <label for="street" class="block text-gray-700 font-medium mb-2">Street</label>
          <input
            v-model="street"
            id="street"
            type="text"
            class="w-full p-3 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Enter street"
          />
        </div>
        <div>
          <label for="radius" class="block text-gray-700 font-medium mb-2">Radius (meters)</label>
          <input
            v-model.number="radius"
            id="radius"
            type="number"
            class="w-full p-3 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Enter radius in meters"
            min="100"
          />
        </div>
      </div>
      <button
        type="submit"
        class="w-full bg-blue-600 text-white py-3 rounded hover:bg-blue-700 transition duration-200"
      >
        Find Bus Stops
      </button>
    </form>

    <div v-if="busStops.length" class="mt-8">
      <h2 class="text-2xl font-semibold mb-4">Nearby Bus Stops:</h2>
      <!-- Copy Table Button -->
      <button
        @click="copyTableToClipboard"
        class="mb-4 bg-green-600 text-white py-2 px-4 rounded hover:bg-green-700 transition duration-200"
      >
        Copy Table to Clipboard
      </button>
      <!-- Table -->
      <div class="max-h-96 overflow-y-auto">
        <table ref="busStopsTable" class="min-w-full bg-white max-h-96">
          <thead>
            <tr>
              <th
                class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase"
              >
                Stop Location
              </th>
              <th
                class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase"
              >
                Stop ID
              </th>
              <th
                class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase"
              >
                Walking Distance (meters)
              </th>
              <th
                class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase"
              >
                Routes Serviced
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(stop, index) in busStops"
              :key="index"
              class="border-b"
            >
              <td class="py-2 px-4">{{ stop.stop_name }}</td>
              <td class="py-2 px-4">{{ stop.stop_id }}</td>
              <td class="py-2 px-4">{{ (stop.distance * 1000).toFixed(1) }}</td>
              <td class="py-2 px-4"></td> <!-- Blank for now -->
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    <!-- Route Frequencies Table -->
    <!-- Route Frequencies Table -->
<div v-if="routeFrequencyTableData.length" class="mt-8">
  <h2 class="text-2xl font-semibold mb-4">Route Frequencies:</h2>
  <div class="max-h-96 overflow-y-auto">
    <table class="min-w-full bg-white max-h-96">
      <thead>
        <tr>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Route</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Direction</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Stop</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Weekday Service Span Start</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Weekday Service Span End</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">AM Headway (min)</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Mid-day Headway (min)</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">PM Headway (min)</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Evening Headway (min)</th>
          <th class="py-2 px-4 bg-gray-200 text-left text-sm font-medium text-gray-700 uppercase">Weekend Headway (min)</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(entry, index) in routeFrequencyTableData" :key="index" class="border-b">
          <td class="py-2 px-4">{{ entry.route }}</td>
          <td class="py-2 px-4">{{ entry.direction }}</td>
          <td class="py-2 px-4">{{ entry.stop }}</td>
          <td class="py-2 px-4">{{ entry.weekdayServiceStart }}</td>
          <td class="py-2 px-4">{{ entry.weekdayServiceEnd }}</td>
          <td class="py-2 px-4">{{ entry.amHeadway }}</td>
          <td class="py-2 px-4">{{ entry.midDayHeadway }}</td>
          <td class="py-2 px-4">{{ entry.pmHeadway }}</td>
          <td class="py-2 px-4">{{ entry.eveningHeadway }}</td>
          <td class="py-2 px-4">{{ entry.weekendHeadway }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</div>

    <div v-if="error" class="text-red-500 mt-4">{{ error }}</div>
  </div>
</template>

<style scoped>
body {
  background-color: #f9fafb;
}

input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 1px #3b82f6;
}
</style>
