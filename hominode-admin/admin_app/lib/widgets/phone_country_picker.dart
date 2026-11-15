import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/country_dial_codes.dart';

/// The existing login selector, shared without changing its appearance.
class PhoneCountrySelector extends StatelessWidget {
  const PhoneCountrySelector({
    super.key,
    required this.selectedCountry,
    required this.onTap,
    this.disabled = false,
    this.useAdminTheme = false,
  });

  final CountryDialCode? selectedCountry;
  final VoidCallback onTap;
  final bool disabled;
  final bool useAdminTheme;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular((useAdminTheme ? 12 : 14).r);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: disabled ? null : onTap,
        child: Ink(
          height: 52.h.clamp(48.0, 56.0),
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: useAdminTheme ? Colors.white : const Color(0xFF0A3034),
            borderRadius: radius,
            border: Border.all(
              color: useAdminTheme
                  ? const Color(0xFFE5E7EB)
                  : disabled
                  ? const Color(0xFF244B48)
                  : const Color(0xFF28675F),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedCountry?.flag ?? '🌐',
                style: TextStyle(fontSize: 16.sp),
              ),

              SizedBox(width: 6.w),

              Text(
                selectedCountry?.dialCode ?? 'country'.tr(),
                style: TextStyle(
                  color: useAdminTheme
                      ? (disabled
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF111111))
                      : (disabled ? const Color(0xFF71948F) : Colors.white),
                  fontSize: 14.sp.clamp(13.0, 15.0),
                  fontWeight: FontWeight.w600,
                ),
              ),

              SizedBox(width: 2.w),

              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: useAdminTheme
                    ? (disabled
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF0E4778))
                    : (disabled
                          ? const Color(0xFF567772)
                          : const Color(0xFF58E3BE)),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The login bottom sheet: name/ISO/dial-code search, flags, selected marker,
/// autofocus, and keyboard dismissal on list drag are shared by both forms.
Future<CountryDialCode?> showPhoneCountryPicker(
  BuildContext context, {
  CountryDialCode? selectedCountry,
  bool useAdminTheme = false,
}) {
  final textColor = useAdminTheme ? const Color(0xFF111111) : Colors.white;
  final borderColor = useAdminTheme
      ? const Color(0xFFE5E7EB)
      : const Color(0xFF28675F);
  final accentColor = useAdminTheme
      ? const Color(0xFF0E4778)
      : const Color(0xFF75E5C9);
  final focusColor = useAdminTheme
      ? const Color(0xFF0E4778)
      : const Color(0xFF58E3BE);
  return showModalBottomSheet<CountryDialCode>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final searchController = TextEditingController();

      var filtered = List<CountryDialCode>.from(kCountryDialCodes);

      return StatefulBuilder(
        builder: (context, setSheetState) {
          void applySearch(String query) {
            final normalized = query.trim().toLowerCase();

            setSheetState(() {
              if (normalized.isEmpty) {
                filtered = List<CountryDialCode>.from(kCountryDialCodes);
              } else {
                filtered = kCountryDialCodes
                    .where((country) => country.matches(normalized))
                    .toList(growable: false);
              }
            });
          }

          return SafeArea(
            top: false,
            child: Container(
              height: MediaQuery.sizeOf(context).height * 0.80,
              decoration: BoxDecoration(
                color: useAdminTheme ? Colors.white : const Color(0xFF061F24),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24.r),
                  topRight: Radius.circular(24.r),
                ),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  SizedBox(height: 10.h),

                  Container(
                    width: 44.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: useAdminTheme
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF41736D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),

                  SizedBox(height: 12.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'select_country_code'.tr(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17.sp.clamp(16.0, 18.0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: Icon(Icons.close, color: accentColor),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      style: TextStyle(color: textColor),
                      onChanged: applySearch,
                      decoration: InputDecoration(
                        hintText: 'search_country_or_code'.tr(),
                        hintStyle: TextStyle(
                          color: useAdminTheme
                              ? const Color(0xFF6B7280)
                              : const Color(0xFF769B95),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: useAdminTheme
                              ? const Color(0xFF0E4778)
                              : const Color(0xFF56E0BC),
                        ),
                        filled: true,
                        fillColor: useAdminTheme
                            ? const Color(0xFFF9FAFB)
                            : const Color(0xFF092D32),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: focusColor, width: 1.4),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'no_countries_found'.tr(),
                              style: TextStyle(
                                color: useAdminTheme
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFFA3C5C0),
                                fontSize: 14.sp,
                              ),
                            ),
                          )
                        : ListView.separated(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: useAdminTheme
                                  ? const Color(0xFFE5E7EB)
                                  : const Color(
                                      0xFF214744,
                                    ).withValues(alpha: 0.8),
                              indent: 16.w,
                              endIndent: 16.w,
                            ),
                            itemBuilder: (context, index) {
                              final country = filtered[index];

                              final selected =
                                  country.isoCode == selectedCountry?.isoCode;

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 1.h,
                                ),
                                leading: Text(
                                  country.flag,
                                  style: TextStyle(fontSize: 20.sp),
                                ),
                                title: Text(
                                  country.name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15.sp,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  country.isoCode,
                                  style: TextStyle(
                                    color: useAdminTheme
                                        ? const Color(0xFF6B7280)
                                        : const Color(0xFF789D97),
                                    fontSize: 12.sp,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      country.dialCode,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (selected) ...[
                                      SizedBox(width: 8.w),
                                      Icon(
                                        Icons.check_circle,
                                        color: focusColor,
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(sheetContext).pop(country);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
