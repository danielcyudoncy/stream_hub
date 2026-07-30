import 'package:stream_hub/modules/epg/models/reminder_model.dart';

abstract class ReminderService {
  Future<List<ReminderModel>> getReminders();

  Future<ReminderModel?> getReminder(String id);

  Future<void> createReminder(ReminderModel reminder);

  Future<void> updateReminder(ReminderModel reminder);

  Future<void> deleteReminder(String id);

  Future<void> toggleReminder(String id, bool active);

  Future<List<ReminderModel>> getActiveReminders();

  Future<List<ReminderModel>> getRemindersForDate(DateTime date);
}