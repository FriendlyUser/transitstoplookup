<template>
  <div class="p-6 max-w-7xl mx-auto bg-white shadow-md rounded-md">
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

    <div v-if="error" class="text-red-500 mt-4">{{ error }}</div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      city: '',
      street: '',
      radius: 800, // Default radius in meters
      busStops: [],
      error: null,
      stopsData: null, // This will hold the parsed stop data
    };
  },
  mounted() {
    // Fetch stops.txt data when the component is mounted
    fetch('/stops.txt')
      .then((response) => response.text())
      .then((data) => {
        this.parseStopsData(data);
      })
      .catch((error) => {
        this.error = 'Error loading bus stop data';
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

    // Perform search based on city and street
    searchLocation() {
      this.error = null;
      this.busStops = [];

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
    },

    // Copy table HTML to clipboard
    copyTableToClipboard() {
      const tableElement = this.$refs.busStopsTable;
      const selection = window.getSelection();
      const range = document.createRange();

      range.selectNodeContents(tableElement);
      selection.removeAllRanges();
      selection.addRange(range);

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

      selection.removeAllRanges();
    },
  },
};
</script>

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
