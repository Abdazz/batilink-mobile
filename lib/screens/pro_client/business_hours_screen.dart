import 'package:batilink_mobile_app/models/business_hours.dart';
import 'package:flutter/material.dart';

class BusinessHoursScreen extends StatefulWidget {
  final List<BusinessHours> initialBusinessHours;
  final Function(List<BusinessHours>) onSave;

  const BusinessHoursScreen({
    Key? key,
    required this.initialBusinessHours,
    required this.onSave,
  }) : super(key: key);

  @override
  _BusinessHoursScreenState createState() => _BusinessHoursScreenState();
}

class _BusinessHoursScreenState extends State<BusinessHoursScreen> {
  late List<BusinessHours> _businessHours;

  @override
  void initState() {
    super.initState();
    _businessHours = List.from(widget.initialBusinessHours);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horaires d\'ouverture'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              widget.onSave(_businessHours);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: _businessHours.map((hours) => _buildBusinessHoursItem(hours)).toList(),
      ),
    );
  }

  Widget _buildBusinessHoursItem(BusinessHours hours) {
    final index = _businessHours.indexOf(hours);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: hours.isOpen,
                  onChanged: (value) {
                    setState(() {
                      _businessHours[index] = hours.copyWith(isOpen: value ?? false);
                    });
                  },
                ),
                Text(
                  hours.day,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (hours.isOpen) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(
                      'Ouverture',
                      hours.openTime ?? const TimeOfDay(hour: 9, minute: 0),
                      (time) {
                        setState(() {
                          _businessHours[index] = hours.copyWith(openTime: time);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePicker(
                      'Fermeture',
                      hours.closeTime ?? const TimeOfDay(hour: 18, minute: 0),
                      (time) {
                        setState(() {
                          _businessHours[index] = hours.copyWith(closeTime: time);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    TimeOfDay initialTime,
    ValueChanged<TimeOfDay> onTimeSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: initialTime,
            );
            if (time != null) {
              onTimeSelected(time);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${initialTime.hour.toString().padLeft(2, '0')}:${initialTime.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
