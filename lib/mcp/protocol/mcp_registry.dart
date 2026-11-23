import 'mcp_error_codes.dart';
import 'mcp_primitives.dart';

/// Central registry for MCP Resources, Tools, Prompts, and domain feature modules.
///
/// Enforces uniqueness across all registered URIs, tool names, prompt names,
/// and module identifiers to prevent silent collisions during modular composition.
class McpRegistry {
  final Map<String, McpResourceDefinition> _resources = {};
  final Map<String, McpToolDefinition> _tools = {};
  final Map<String, McpPromptDefinition> _prompts = {};
  final Set<String> _registeredModules = {};

  int get resourceCount => _resources.length;
  int get toolCount => _tools.length;
  int get promptCount => _prompts.length;
  List<String> get registeredModules =>
      List.unmodifiable(_registeredModules);

  bool hasResource(String uri) => _resources.containsKey(uri);
  bool hasTool(String name) => _tools.containsKey(name);
  bool hasPrompt(String name) => _prompts.containsKey(name);

  /// Registers a read-only MCP Resource, rejecting duplicate URIs.
  void registerResource(McpResourceDefinition definition) {
    if (definition.uri.trim().isEmpty) {
      throw ArgumentError.value(
        definition.uri,
        'definition.uri',
        'Resource URI must not be empty.',
      );
    }
    if (_resources.containsKey(definition.uri)) {
      throw ArgumentError(
        'Duplicate MCP resource URI registered: ${definition.uri}',
      );
    }
    _resources[definition.uri] = definition;
  }

  /// Registers an executable MCP Tool, rejecting duplicate tool names.
  void registerTool(McpToolDefinition definition) {
    if (definition.name.trim().isEmpty) {
      throw ArgumentError.value(
        definition.name,
        'definition.name',
        'Tool name must not be empty.',
      );
    }
    if (_tools.containsKey(definition.name)) {
      throw ArgumentError(
        'Duplicate MCP tool name registered: ${definition.name}',
      );
    }
    _tools[definition.name] = definition;
  }

  /// Registers a guided MCP Prompt, rejecting duplicate prompt names.
  void registerPrompt(McpPromptDefinition definition) {
    if (definition.name.trim().isEmpty) {
      throw ArgumentError.value(
        definition.name,
        'definition.name',
        'Prompt name must not be empty.',
      );
    }
    if (_prompts.containsKey(definition.name)) {
      throw ArgumentError(
        'Duplicate MCP prompt name registered: ${definition.name}',
      );
    }
    _prompts[definition.name] = definition;
  }

  /// Registers all primitives exposed by [module], preventing duplicate module names.
  void registerModule(IMcpFeatureModule module) {
    final name = module.moduleName.trim();
    if (name.isEmpty) {
      throw ArgumentError('MCP feature module name must not be empty.');
    }
    if (_registeredModules.contains(name)) {
      throw ArgumentError('Duplicate MCP feature module registered: $name');
    }
    _registeredModules.add(name);
    module.register(this);
  }

  /// Returns all registered Resource descriptors for `resources/list`.
  List<Map<String, dynamic>> listResources() {
    return _resources.values
        .map((r) => r.toDescriptorJson())
        .toList(growable: false);
  }

  /// Reads the content of the Resource identified by [uri].
  Future<McpResourceContent> readResource(String uri) async {
    final definition = _resources[uri];
    if (definition == null) {
      throw McpException.fileNotFound('MCP resource not found: $uri');
    }
    return definition.reader();
  }

  /// Returns all registered Tool descriptors for `tools/list`.
  List<Map<String, dynamic>> listTools() {
    return _tools.values
        .map((t) => t.toDescriptorJson())
        .toList(growable: false);
  }

  /// Executes the Tool identified by [name] with validated [arguments].
  Future<McpToolResult> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final definition = _tools[name];
    if (definition == null) {
      throw McpException.methodNotFound('MCP tool not found: $name');
    }
    return definition.handler(arguments);
  }

  /// Returns all registered Prompt descriptors for `prompts/list`.
  List<Map<String, dynamic>> listPrompts() {
    return _prompts.values
        .map((p) => p.toDescriptorJson())
        .toList(growable: false);
  }

  /// Resolves the Prompt identified by [name] with [arguments].
  Future<McpPromptResult> getPrompt(
    String name,
    Map<String, String> arguments,
  ) async {
    final definition = _prompts[name];
    if (definition == null) {
      throw McpException.methodNotFound('MCP prompt not found: $name');
    }

    for (final arg in definition.arguments) {
      if (arg.required) {
        final value = arguments[arg.name];
        if (value == null || value.trim().isEmpty) {
          throw McpException.invalidParams(
            'Missing required argument "${arg.name}" for prompt "$name".',
          );
        }
      }
    }

    return definition.builder(arguments);
  }
}
