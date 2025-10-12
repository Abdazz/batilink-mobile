import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

// API Configuration
const String apiBaseUrl = 'http://10.0.2.2:8000/api';

// Colors
const primaryColor = Color(0xFF255ED6);
const textColor = Color(0xFF35364F);
const backgroundColor = Color(0xFFE6EFF9);
const redColor = Color(0xFFE85050);

// Dimensions
const defaultPadding = 16.0;

// Widgets
OutlineInputBorder textFieldBorder = OutlineInputBorder(
  borderSide: BorderSide(
    color: primaryColor.withOpacity(0.1),
  ),
);

// Validation Messages
const emailError = 'Enter a valid email address';
const requiredField = "This field is required";

final passwordValidator = MultiValidator(
  [
    RequiredValidator(errorText: 'password is required'),
    MinLengthValidator(8, errorText: 'password must be at least 8 digits long'),
    PatternValidator(r'(?=.*?[#?!@$%^&*-])',
        errorText: 'passwords must have at least one special character')
  ],
);


