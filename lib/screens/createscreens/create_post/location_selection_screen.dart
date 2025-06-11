import 'package:flutter/material.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({Key? key}) : super(key: key);

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredLocations = [];
  bool _isSearching = false;

  // List of 50 popular cities
  final List<String> _allLocations = [
    'New York, USA',
    'London, UK',
    'Paris, France',
    'Tokyo, Japan',
    'Sydney, Australia',
    'Mumbai, India',
    'Surat, India',
    'Bangalore, India',
    'Delhi, India',
    'Chennai, India',
    'Kolkata, India',
    'Hyderabad, India',
    'Ahmedabad, India',
    'Pune, India',
    'Jaipur, India',
    'Lucknow, India',
    'Kanpur, India',
    'Nagpur, India',
    'Patna, India',
    'Indore, India',
    'Thane, India',
    'Bhopal, India',
    'Visakhapatnam, India',
    'Vadodara, India',
    'Ghaziabad, India',
    'Ludhiana, India',
    'Agra, India',
    'Nashik, India',
    'Faridabad, India',
    'Meerut, India',
    'Rajkot, India',
    'Varanasi, India',
    'Srinagar, India',
    'Dhanbad, India',
    'Amritsar, India',
    'Navi Mumbai, India',
    'Allahabad, India',
    'Ranchi, India',
    'Jabalpur, India',
    'Kota, India',
    'Jodhpur, India',
    'Guwahati, India',
    'Solapur, India',
    'Coimbatore, India',
    'Vijayawada, India',
    'Hubli-Dharwad, India',
    'Moradabad, India',
    'Mysore, India',
    'Gurgaon, India',
    'Aligarh, India',
    'Jalandhar, India',
    'Bhubaneswar, India',
    'Salem, India',
    'Mira-Bhayandar, India',
    'Thiruvananthapuram, India',
    'Bhiwandi, India',
    'Saharanpur, India',
    'Gorakhpur, India',
    'Amravati, India',
    'Gwalior, India',
    'Noida, India',
    'Kuwait'
    'Sharjah, United Arab Emirates',
    'Dubai, United Arab Emirates',
    'Abu Dhabi, United Arab Emirates',
    'Ajman, United Arab Emirates',
    'Karbala, Iraq',
    'Baghdad, Iraq',
    'Riyadh, Saudi Arabia',
    'Mecca, Saudi Arabia',
    'Medina, Saudi Arabia',
    'Doha, Qatar',
    'Bahrain',
    'Beijing, China',
    'Sao Paulo, Brazil',
    'Buenos Aires, Argentina',
    'Bangkok, Thailand',
    'Singapore',
    'Hong Kong',
    'Los Angeles, USA',
    'Chicago, USA',
    'Toronto, Canada',
    'Berlin, Germany',
    'Rome, Italy',
    'Madrid, Spain',
    'Amsterdam, Netherlands',
    'Bangkok, Thailand',
    'Seoul, South Korea',
    'Shanghai, China',
    'Moscow, Russia',
    'Istanbul, Turkey',
    'Cairo, Egypt',
    'Rio de Janeiro, Brazil',
    'Mexico City, Mexico',
    'Barcelona, Spain',
    'Vienna, Austria',
    'Prague, Czech Republic',
    'Budapest, Hungary',
    'Warsaw, Poland',
    'Athens, Greece',
    'Lisbon, Portugal',
    'Dublin, Ireland',
    'Stockholm, Sweden',
    'Oslo, Norway',
    'Copenhagen, Denmark',
    'Helsinki, Finland',
    'Brussels, Belgium',
    'Zurich, Switzerland',
    'Vienna, Austria',
    'Munich, Germany',
    'Milan, Italy',
    'Venice, Italy',
    'Florence, Italy',
    'Barcelona, Spain',
    'Seville, Spain',
    'Porto, Portugal',
    'Edinburgh, UK',
    'Glasgow, UK',
    'Manchester, UK',
    'Birmingham, UK',
  ];

  @override
  void initState() {
    super.initState();
    _filteredLocations = List.from(_allLocations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterLocations(String query) {
    setState(() {
      _filteredLocations = _allLocations
          .where((location) =>
              location.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Location',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search locations',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterLocations,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredLocations.length,
              itemBuilder: (context, index) {
                final location = _filteredLocations[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                  title: Text(
                    location,
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context, location);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 