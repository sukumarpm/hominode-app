import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

class DeletionTestAssetLoader extends AssetLoader {
  const DeletionTestAssetLoader();

  static const _english = <String, dynamic>{
    'delete_account': 'Delete Account',
    'deletion_title': 'Request account deletion',
    'deletion_confirm_title': 'Request account deletion?',
    'deletion_intro':
        'Confirm your request and verify your identity if prompted. Deletion happens only after required safety checks.',
    'deletion_records_notice':
        'Required financial and security records may be retained under the published policy.',
    'deletion_pending_dues':
        'Outstanding dues: settlement must be confirmed before deletion can continue.',
    'deletion_unknown_finances':
        'Financial status: requires reconciliation before deletion can continue.',
    'deletion_zero_finances':
        'Financial status: zero dues; awaiting Community Admin verification.',
    'deletion_account_active':
        'Your account has not been deleted and remains active while this request is reviewed.',
    'deletion_next_steps':
        'What happens next: your Community Admin reviews financial settlement, then the system rechecks all requirements.',
    'deletion_next_steps_processing':
        'What happens next: the system checks the remaining requirements and updates this request.',
    'deletion_reference': 'Reference: {reference}',
    'deletion_status_completed': 'Completed',
    'deletion_status_pending_admin': 'Pending Community Admin review',
    'deletion_status_pending_processing': 'Pending processing review',
    'deletion_status_processing': 'Processing',
    'deletion_status_verification': 'Verification required',
    'deletion_status_failed': 'Could not complete processing',
    'deletion_request_button': 'Request account deletion',
    'deletion_continue_button': 'Continue request',
    'deletion_verify_identity_button': 'Verify identity',
    'deletion_verify_otp_button': 'Verify OTP',
    'deletion_refresh_button': 'Refresh status',
    'deletion_retry_status_button': 'Retry status',
    'deletion_retry_processing_button': 'Retry processing',
    'deletion_signing_out': 'Signing out…',
    'deletion_otp_label': 'OTP code',
    'deletion_error_load': 'Could not load request status. Please retry.',
    'deletion_error_verify':
        'Verification failed. Check the code and try again.',
    'deletion_error_reauth':
        'Verification required. Verify your identity to continue this request.',
    'deletion_error_unconfirmed':
        'Final status is not confirmed. Processing may still continue. Refresh status to check the same request.',
    'deletion_error_processing':
        'Processing failed. Retry to continue the same request.',
    'deletion_error_refresh':
        'Request received, but status could not be refreshed. Check again.',
    'deletion_error_signout': 'Could not sign out. Please try again.',
    'deletion_error_deleted_signout':
        'Your account was deleted. Retrying local sign-out…',
    'deletion_success': 'Account deleted successfully',
    'deletion_cancel': 'Cancel',
    'deletion_confirm_button': 'Confirm request',
    'deletion_sign_out_button': 'Sign out',
    'deletion_loading': 'Loading status…',
    'deletion_activity_sending_otp': 'Sending OTP…',
    'deletion_activity_verifying_otp': 'Verifying OTP…',
    'deletion_activity_processing': 'Processing…',
  };

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      _english;
}
