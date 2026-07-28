import 'package:get/get.dart';

class AppTranslations extends Translations {
  static const String titleSettings = 'settings_title';
  static const String titleProfile = 'profile_title';
  static const String titleProviderManager = 'provider_manager_title';
  static const String titleAbout = 'about_title';
  static const String titleStorage = 'storage_title';
  static const String titleDashboard = 'dashboard_title';
  static const String titleLogin = 'login_title';

  static const String labelSave = 'label_save';
  static const String labelCancel = 'label_cancel';
  static const String labelDelete = 'label_delete';
  static const String labelEdit = 'label_edit';
  static const String labelAdd = 'label_add';
  static const String labelSearch = 'label_search';

  static const String messageProviderCreated = 'message_provider_created';
  static const String messageProviderUpdated = 'message_provider_updated';
  static const String messageProviderDeleted = 'message_provider_deleted';
  static const String messageProfileSaved = 'message_profile_saved';
  static const String messageCacheCleared = 'message_cache_cleared';

  static const String errorFailedToLoad = 'error_failed_to_load';
  static const String errorFailedToSave = 'error_failed_to_save';
  static const String errorProviderNameExists = 'error_provider_name_exists';

  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          titleSettings: 'Settings',
          titleProfile: 'Profile',
          titleProviderManager: 'Provider Manager',
          titleAbout: 'About',
          titleStorage: 'Storage',
          titleDashboard: 'Dashboard',
          titleLogin: 'Login',
          labelSave: 'Save',
          labelCancel: 'Cancel',
          labelDelete: 'Delete',
          labelEdit: 'Edit',
          labelAdd: 'Add',
          labelSearch: 'Search',
          messageProviderCreated: 'Provider created successfully',
          messageProviderUpdated: 'Provider updated successfully',
          messageProviderDeleted: 'Provider deleted successfully',
          messageProfileSaved: 'Profile saved successfully',
          messageCacheCleared: 'Cache cleared successfully',
          errorFailedToLoad: 'Failed to load data',
          errorFailedToSave: 'Failed to save data',
          errorProviderNameExists: 'A provider with this name already exists',
        },
      };
}
