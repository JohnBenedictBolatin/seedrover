import 'permission_keys.dart';

/// Navigation intent only: opening a task never submits it.
enum WorkspaceAction {
  recordSale('record-sale', 'Record sale', PermissionKeys.stocksSalesRecord, true),
  receiveStock('receive-stock', 'Receive stock', PermissionKeys.stocksManage, true),
  issueStock('issue-stock', 'Issue stock', PermissionKeys.stocksManage, true),
  recordCare('record-care', 'Record care', PermissionKeys.cropsManage, false),
  observeGrowth('observe-growth', 'Observe growth', PermissionKeys.cropsManage, false);
  const WorkspaceAction(this.query, this.label, this.permission, this.isInventory);
  final String query;
  final String label;
  final String permission;
  final bool isInventory;
  static WorkspaceAction? parse(String? value) {
    for (final action in values) {
      if (action.query == value) return action;
    }
    return null;
  }
}
