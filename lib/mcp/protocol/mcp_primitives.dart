import 'dart:convert';

import 'package:meta/meta.dart';

import 'mcp_registry.dart';

/// Content payload returned by reading an MCP Resource (`resources/read`).
@immutable
class McpResourceContent {
  final String uri;
  final String mimeType;
  final String? text;
  final String? blob;

  const McpResourceContent({
    required this.uri,
    required this.mimeType,
    this.text,
    this.blob,
  });

  factory McpResourceContent.text({
    required String uri,
    required String text,
    String mimeType = 'text/plain',
  }) {
    return McpResourceContent(
      uri: uri,
      mimeType: mimeType,
      text: text,
    );
  }

  factory McpResourceContent.json({
    required String uri,
    required Object data,
    String mimeType = 'application/json',
  }) {
    return McpResourceContent(
      uri: uri,
      mimeType: mimeType,
      text: jsonEncode(data),
    );
  }

  factory McpResourceContent.blob({
    required String uri,
    required String base64Data,
    String mimeType = 'application/octet-stream',
  }) {
    return McpResourceContent(
      uri: uri,
      mimeType: mimeType,
      blob: base64Data,
    );
  }

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'mimeType': mimeType,
        if (text != null) 'text': text,
        if (blob != null) 'blob': blob,
      };
}

/// Registration contract for a read-only MCP Resource (`tunner://...`).
@immutable
class McpResourceDefinition {
  final String uri;
  final String name;
  final String description;
  final String mimeType;
  final Future<McpResourceContent> Function() reader;

  const McpResourceDefinition({
    required this.uri,
    required this.name,
    required this.description,
    required this.mimeType,
    required this.reader,
  });

  Map<String, dynamic> toDescriptorJson() => {
        'uri': uri,
        'name': name,
        'description': description,
        'mimeType': mimeType,
      };
}

/// Result returned by executing an MCP Tool (`tools/call`).
@immutable
class McpToolResult {
  final List<Map<String, dynamic>> content;
  final Map<String, dynamic>? structuredData;
  final bool isError;

  const McpToolResult({
    required this.content,
    this.structuredData,
    this.isError = false,
  });

  /// Creates a successful JSON tool result with optional human-readable [summary].
  factory McpToolResult.json(
    Map<String, dynamic> data, {
    String? summary,
  }) {
    return McpToolResult(
      content: [
        {
          'type': 'text',
          'text': summary ?? jsonEncode(data),
        },
      ],
      structuredData: data,
      isError: false,
    );
  }

  /// Creates a successful plain-text tool result.
  factory McpToolResult.text(
    String text, {
    Map<String, dynamic>? structuredData,
  }) {
    return McpToolResult(
      content: [
        {
          'type': 'text',
          'text': text,
        },
      ],
      structuredData: structuredData,
      isError: false,
    );
  }

  /// Creates a tool-level error result compliant with MCP (`isError: true`).
  factory McpToolResult.error(
    String message, {
    Map<String, dynamic>? details,
  }) {
    return McpToolResult(
      content: [
        {
          'type': 'text',
          'text': message,
        },
      ],
      structuredData: details,
      isError: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        if (structuredData != null) 'structuredData': structuredData,
        'isError': isError,
      };
}

/// Registration contract for an executable MCP Tool (`tunner_*`).
@immutable
class McpToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final Future<McpToolResult> Function(Map<String, dynamic> arguments) handler;

  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  Map<String, dynamic> toDescriptorJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// Formal argument descriptor for an MCP Prompt template.
@immutable
class McpPromptArgument {
  final String name;
  final String description;
  final bool required;

  const McpPromptArgument({
    required this.name,
    required this.description,
    this.required = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'required': required,
      };
}

/// Individual message entry returned by `prompts/get`.
@immutable
class McpPromptMessage {
  final String role;
  final String text;

  const McpPromptMessage({
    required this.role,
    required this.text,
  });

  const McpPromptMessage.user(String text) : this(role: 'user', text: text);

  const McpPromptMessage.assistant(String text)
      : this(role: 'assistant', text: text);

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': {
          'type': 'text',
          'text': text,
        },
      };
}

/// Resolved prompt payload returned by `prompts/get`.
@immutable
class McpPromptResult {
  final String description;
  final List<McpPromptMessage> messages;

  const McpPromptResult({
    required this.description,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'messages': messages.map((m) => m.toJson()).toList(growable: false),
      };
}

/// Registration contract for a guided MCP Prompt workflow.
@immutable
class McpPromptDefinition {
  final String name;
  final String description;
  final List<McpPromptArgument> arguments;
  final Future<McpPromptResult> Function(Map<String, String> arguments) builder;

  const McpPromptDefinition({
    required this.name,
    required this.description,
    this.arguments = const [],
    required this.builder,
  });

  Map<String, dynamic> toDescriptorJson() => {
        'name': name,
        'description': description,
        'arguments': arguments.map((a) => a.toJson()).toList(growable: false),
      };
}

/// Modular feature registration interface implemented by each domain MCP module.
abstract interface class IMcpFeatureModule {
  /// Unique human-readable module identifier (e.g., `core_audio`, `notation_editor`).
  String get moduleName;

  /// Registers all Resources, Tools, and Prompts owned by this module into [registry].
  void register(McpRegistry registry);
}
