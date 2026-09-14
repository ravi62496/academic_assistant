import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_schedule.dart';
import '../models/course.dart';

class AiToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'arguments': arguments,
    };
  }
}

class AiResponse {
  final String? text;
  final List<AiToolCall> toolCalls;

  AiResponse({
    this.text,
    required this.toolCalls,
  });
}

class AiAssistantService {
  final SupabaseClient _client;

  AiAssistantService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Loads persistent chat history from Supabase table 'ai_chat_messages'
  Future<List<Map<String, dynamic>>> loadChatHistory({int limit = 50}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('ai_chat_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Note: Could not load chat history from Supabase ai_chat_messages: $e');
      return [];
    }
  }

  /// Saves a single chat turn (user or assistant) to Supabase table 'ai_chat_messages'
  Future<void> saveChatMessage({
    required String role,
    String? content,
    List<Map<String, dynamic>>? toolCalls,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('ai_chat_messages').insert({
        'user_id': userId,
        'role': role,
        'content': content ?? '',
        if (toolCalls != null && toolCalls.isNotEmpty) 'tool_calls': toolCalls,
      });
    } catch (e) {
      debugPrint('Note: Could not save chat message to Supabase ai_chat_messages: $e');
    }
  }

  /// Deletes persistent chat history for current user from Supabase table 'ai_chat_messages'
  Future<void> clearChatHistory() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('ai_chat_messages').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Note: Could not clear chat history from Supabase: $e');
    }
  }

  /// Send user message and/or timetable image to Supabase Edge Function 'ai-assistant',
  /// with automatic direct API fallback if Edge Function is missing or fails.
  Future<AiResponse> sendMessage({
    String? message,
    String? imageBase64,
    required List<Course> courses,
    required List<ClassSchedule> classes,
    List<Map<String, dynamic>>? history,
  }) async {
    // 1. Try Supabase Edge Function first
    try {
      final response = await _client.functions.invoke(
        'ai-assistant',
        body: {
          if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
          if (imageBase64 != null && imageBase64.isNotEmpty) 'image_base64': imageBase64,
          'courses': courses.map((c) => c.toJson()).toList(),
          'classes': classes.map((c) => c.toJson()).toList(),
          if (history != null && history.isNotEmpty) 'history': history,
        },
      ).timeout(
        const Duration(seconds: 15),
      );

      final data = response.data;
      if (data != null) {
        Map<String, dynamic> jsonResponse;
        if (data is String) {
          jsonResponse = jsonDecode(data) as Map<String, dynamic>;
        } else if (data is Map<String, dynamic>) {
          jsonResponse = data;
        } else {
          throw Exception('Unexpected response format from Edge Function.');
        }

        if (!jsonResponse.containsKey('error')) {
          return _parseResponseJson(jsonResponse);
        }
      }
    } catch (edgeError) {
      debugPrint('Edge Function invoke failed or unavailable: $edgeError. Trying direct API fallback...');
    }

    // 2. Direct API Fallback using NVIDIA API Key from .env
    final nvidiaKey = dotenv.env['NVIDIA_API_KEY'] ?? '';
    if (nvidiaKey.isNotEmpty) {
      try {
        return await _sendDirectNvidiaApiMessage(
          message: message,
          imageBase64: imageBase64,
          courses: courses,
          classes: classes,
          history: history,
          apiKey: nvidiaKey,
        );
      } catch (directError) {
        debugPrint('Direct NVIDIA API call error: $directError');
        throw Exception('Failed to connect to AI Assistant service: $directError');
      }
    }

    throw Exception(
        'AI Assistant service unavailable. Please ensure your network connection is active or check your .env configuration.');
  }

  AiResponse _parseResponseJson(Map<String, dynamic> jsonResponse) {
    final choices = jsonResponse['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Invalid or empty choices array in response.');
    }

    final messageData = choices[0]['message'] as Map<String, dynamic>?;
    if (messageData == null) {
      throw Exception('Missing message object in response.');
    }

    final text = messageData['content'] as String?;
    final rawToolCalls = messageData['tool_calls'] as List<dynamic>?;

    final toolCalls = <AiToolCall>[];
    if (rawToolCalls != null) {
      for (final tc in rawToolCalls) {
        final id = tc['id'] as String? ?? '';
        final function = tc['function'] as Map<String, dynamic>?;
        if (function != null) {
          final name = function['name'] as String? ?? '';
          final rawArgs = function['arguments'];
          Map<String, dynamic> parsedArgs = {};
          if (rawArgs is String) {
            try {
              parsedArgs = jsonDecode(rawArgs) as Map<String, dynamic>;
            } catch (e) {
              debugPrint('Error parsing tool call arguments JSON: $e');
            }
          } else if (rawArgs is Map<String, dynamic>) {
            parsedArgs = rawArgs;
          }
          toolCalls.add(AiToolCall(
            id: id,
            name: name,
            arguments: parsedArgs,
          ));
        }
      }
    }

    return AiResponse(
      text: text,
      toolCalls: toolCalls,
    );
  }

  Future<AiResponse> _sendDirectNvidiaApiMessage({
    String? message,
    String? imageBase64,
    required List<Course> courses,
    required List<ClassSchedule> classes,
    List<Map<String, dynamic>>? history,
    required String apiKey,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    final systemPrompt = '''You are Sentry, an AI Academic Assistant for a student app.
Current Date/Time: $nowStr
Current Courses: ${jsonEncode(courses.map((c) => c.toJson()).toList())}
Current Recurring Class Schedules: ${jsonEncode(classes.map((c) => c.toJson()).toList())}

Your job:
1. Help the student manage their schedule, courses, and tasks.
2. If the user wants to add, edit, cancel, or reschedule a course or class, invoke the corresponding tool.
3. If an image is provided, extract all printed/written class details and call `import_schedule_from_image`.
4. Be helpful, concise, and accurate.''';

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    if (history != null) {
      for (final h in history) {
        messages.add({
          'role': h['role'] ?? 'user',
          'content': h['content'] ?? '',
        });
      }
    }

    if (imageBase64 != null && imageBase64.isNotEmpty) {
      messages.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': message ?? 'Analyze this timetable image and extract all classes into import_schedule_from_image tool call.'},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'}
          }
        ]
      });
    } else if (message != null && message.trim().isNotEmpty) {
      messages.add({'role': 'user', 'content': message.trim()});
    }

    final tools = [
      {
        'type': 'function',
        'function': {
          'name': 'add_course',
          'description': 'Add a new course / subject for the student',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'Full course name e.g. Data Structures'},
              'code': {'type': 'string', 'description': 'Course code e.g. CS201'},
              'professor': {'type': 'string', 'description': 'Professor name'},
            },
            'required': ['name'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'update_course',
          'description': 'Update an existing course details',
          'parameters': {
            'type': 'object',
            'properties': {
              'course_id': {'type': 'string'},
              'name': {'type': 'string'},
              'code': {'type': 'string'},
              'professor': {'type': 'string'},
            },
            'required': ['course_id'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_course',
          'description': 'Delete a course by ID',
          'parameters': {
            'type': 'object',
            'properties': {
              'course_id': {'type': 'string'},
            },
            'required': ['course_id'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'add_class',
          'description': 'Add a recurring weekly class schedule',
          'parameters': {
            'type': 'object',
            'properties': {
              'course_id': {'type': 'string'},
              'day_of_week': {'type': 'integer', 'description': '1=Monday ... 7=Sunday'},
              'start_time': {'type': 'string', 'description': 'HH:mm format e.g. 09:00'},
              'end_time': {'type': 'string', 'description': 'HH:mm format e.g. 10:30'},
              'room': {'type': 'string'},
            },
            'required': ['course_id', 'day_of_week', 'start_time', 'end_time'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'update_class',
          'description': 'Update an existing recurring class schedule slot',
          'parameters': {
            'type': 'object',
            'properties': {
              'class_id': {'type': 'string'},
              'course_id': {'type': 'string'},
              'day_of_week': {'type': 'integer'},
              'start_time': {'type': 'string'},
              'end_time': {'type': 'string'},
              'room': {'type': 'string'},
            },
            'required': ['class_id'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_class',
          'description': 'Delete a recurring class schedule slot',
          'parameters': {
            'type': 'object',
            'properties': {
              'class_id': {'type': 'string'},
            },
            'required': ['class_id'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'add_override',
          'description': 'Cancel or reschedule a class for a specific date',
          'parameters': {
            'type': 'object',
            'properties': {
              'class_id': {'type': 'string'},
              'date': {'type': 'string', 'description': 'YYYY-MM-DD format'},
              'type': {'type': 'string', 'enum': ['cancelled', 'rescheduled']},
              'new_start_time': {'type': 'string'},
              'new_end_time': {'type': 'string'},
              'new_room': {'type': 'string'},
              'new_day_of_week': {'type': 'integer'},
            },
            'required': ['class_id', 'date', 'type'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'import_schedule_from_image',
          'description': 'Import extracted classes from timetable image',
          'parameters': {
            'type': 'object',
            'properties': {
              'entries': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'course_name': {'type': 'string'},
                    'course_code': {'type': 'string'},
                    'professor': {'type': 'string'},
                    'day_of_week': {'type': 'integer', 'description': '1=Mon..7=Sun'},
                    'start_time': {'type': 'string', 'description': 'HH:mm'},
                    'end_time': {'type': 'string', 'description': 'HH:mm'},
                    'room': {'type': 'string'},
                  },
                  'required': ['course_name', 'day_of_week', 'start_time', 'end_time'],
                }
              }
            },
            'required': ['entries'],
          }
        }
      },
    ];

    final modelName = imageBase64 != null && imageBase64.isNotEmpty
        ? 'meta/llama-3.2-11b-vision-instruct'
        : 'meta/llama-3.3-70b-instruct';

    final uri = Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': modelName,
        'messages': messages,
        'tools': tools,
        'tool_choice': 'auto',
        'temperature': 0.2,
      }),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) {
      throw Exception('API returned status ${response.statusCode}: ${response.body}');
    }

    final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseResponseJson(jsonResponse);
  }
}
