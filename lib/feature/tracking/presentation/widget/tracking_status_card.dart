import 'package:flutter/material.dart';

class TrackingStatusCard extends StatelessWidget {
  final int total;

  const TrackingStatusCard({
    super.key,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [

            _row(
              Icons.gps_fixed,
              "GPS",
              "Active",
              Colors.green,
            ),

            const Divider(),

            _row(
              Icons.cloud_done,
              "Sync",
              "Online",
              Colors.blue,
            ),

            const Divider(),

            _row(
              Icons.storage,
              "Stored Data",
              "$total",
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
      IconData icon,
      String title,
      String value,
      Color color,
      ) {
    return Row(
      children: [

        CircleAvatar(
          backgroundColor: color.withOpacity(.15),
          child: Icon(
            icon,
            color: color,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),

        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        )
      ],
    );
  }
}