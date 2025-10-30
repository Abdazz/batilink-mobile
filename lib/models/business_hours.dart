import 'package:flutter/material.dart';

class BusinessHours {
  final String day;
  final bool isOpen;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;

  BusinessHours({
    required this.day,
    this.isOpen = false,
    this.openTime,
    this.closeTime,
  });

  factory BusinessHours.fromJson(Map<String, dynamic> json) {
    return BusinessHours(
      day: json['day'],
      isOpen: json['is_open'] ?? false,
      openTime: json['open_time'] != null 
          ? TimeOfDay(
              hour: int.parse(json['open_time'].split(':')[0]),
              minute: int.parse(json['open_time'].split(':')[1]),
            )
          : null,
      closeTime: json['close_time'] != null
          ? TimeOfDay(
              hour: int.parse(json['close_time'].split(':')[0]),
              minute: int.parse(json['close_time'].split(':')[1]),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'is_open': isOpen,
      'open_time': isOpen && openTime != null 
          ? '${openTime!.hour.toString().padLeft(2, '0')}:${openTime!.minute.toString().padLeft(2, '0')}'
          : null,
      'close_time': isOpen && closeTime != null
          ? '${closeTime!.hour.toString().padLeft(2, '0')}:${closeTime!.minute.toString().padLeft(2, '0')}'
          : null,
    };
  }

  BusinessHours copyWith({
    String? day,
    bool? isOpen,
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
  }) {
    return BusinessHours(
      day: day ?? this.day,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}
