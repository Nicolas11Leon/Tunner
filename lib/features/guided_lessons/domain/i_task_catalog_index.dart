import 'pedagogical_task_contract.dart';
import 'task_taxonomy_code.dart';

/// Contrato de dominio puro para el índice de búsqueda e inventario
/// de tareas pedagógicas en memoria.
abstract class ITaskCatalogIndex {
  int get count;
  List<PedagogicalTaskEntity> get allTasks;

  void register(PedagogicalTaskEntity task);
  void registerAll(Iterable<PedagogicalTaskEntity> tasks);

  PedagogicalTaskEntity? getByCode(TaskTaxonomyCode code);
  PedagogicalTaskEntity? getByCodeString(String formattedCode);

  List<PedagogicalTaskEntity> searchByQuery(String query, {int limit = 20});

  List<PedagogicalTaskEntity> filter({
    TaskDomain? domain,
    TaskLevel? level,
    TaskCompletionStatus? status,
    String? instrumentId,
  });

  List<PedagogicalTaskEntity> getMultiToolJointTasks();
}
