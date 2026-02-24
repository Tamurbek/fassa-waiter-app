import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pos_controller_state.dart';

mixin TableMixin on POSControllerState {
  void updateTablePosition(String tableId, double x, double y) {
    tablePositions[tableId] = {"x": x, "y": y};
    tablePositions.refresh();
  }

  Future<void> syncTablePositionWithBackend(String tableId) async {
    final String? backendId = tableBackendIds[tableId];
    if (backendId == null) return;

    final pos = tablePositions[tableId];
    if (pos == null) return;

    try {
      await api.updateTable(backendId, {
        "x": pos['x'],
        "y": pos['y'],
      });
      storage.write('table_positions', Map.from(tablePositions));
    } catch (e) {
      print("Error syncing table position: $e");
    }
  }

  Future<void> updateAreaDimensions(String areaName, double width, double height) async {
    final String? areaId = tableAreaBackendIds[areaName];
    if (areaId == null) return;

    try {
      await api.updateTableArea(areaId, {
        "name": areaName,
        "width_m": width,
        "height_m": height,
      });
      tableAreaDetails[areaName] = {"width_m": width, "height_m": height};
      tableAreaDetails.refresh();
    } catch (e) {
      print("Error updating area dimensions: $e");
    }
  }
}
