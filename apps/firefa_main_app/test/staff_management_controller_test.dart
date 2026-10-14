import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/staff/staff_management_controller.dart';
import 'package:firefa_main_app/features/staff/staff_user_model.dart';

void main() {
  group('StaffManagementController', () {
    test('adds normalized staff and finds by ID', () {
      final controller = StaffManagementController();
      controller.addStaff(const StaffUserModel(
        id: ' STAFF-01 ',
        name: '  Andi  ',
        role: ' Cashier ',
      ));

      expect(controller.staff.single.id, 'STAFF-01');
      expect(controller.staff.single.name, 'Andi');
      expect(controller.staff.single.role, 'Cashier');
      expect(controller.findById(' STAFF-01 ')?.name, 'Andi');
    });

    test('rejects duplicate IDs and invalid fields', () {
      final controller = StaffManagementController();
      controller.addStaff(const StaffUserModel(
        id: 'STAFF-01',
        name: 'Andi',
        role: 'Cashier',
      ));

      expect(
        () => controller.addStaff(const StaffUserModel(
          id: ' STAFF-01 ',
          name: 'Budi',
          role: 'Manager',
        )),
        throwsStateError,
      );
      expect(
        () => controller.addStaff(const StaffUserModel(
          id: ' ',
          name: 'Budi',
          role: 'Manager',
        )),
        throwsArgumentError,
      );
      expect(
        () => controller.addStaff(const StaffUserModel(
          id: 'STAFF-02',
          name: ' ',
          role: 'Manager',
        )),
        throwsArgumentError,
      );
      expect(controller.staff, hasLength(1));
    });

    test('updates staff and prevents ID collisions', () {
      final controller = StaffManagementController();
      controller.addStaff(const StaffUserModel(
        id: 'STAFF-01',
        name: 'Andi',
        role: 'Cashier',
      ));
      controller.addStaff(const StaffUserModel(
        id: 'STAFF-02',
        name: 'Budi',
        role: 'Manager',
      ));

      expect(
        controller.updateStaff(
          'STAFF-01',
          const StaffUserModel(
            id: 'STAFF-01',
            name: 'Andi Wijaya',
            role: 'Manager',
          ),
        ),
        isTrue,
      );
      expect(controller.findById('STAFF-01')?.name, 'Andi Wijaya');
      expect(
        () => controller.updateStaff(
          'STAFF-01',
          const StaffUserModel(
            id: 'STAFF-02',
            name: 'Andi Wijaya',
            role: 'Manager',
          ),
        ),
        throwsStateError,
      );
      expect(
        controller.updateStaff(
          'MISSING',
          const StaffUserModel(
            id: 'STAFF-03',
            name: 'New',
            role: 'Cashier',
          ),
        ),
        isFalse,
      );
    });

    test('searches by ID, name, or role without case sensitivity', () {
      final controller = StaffManagementController();
      controller.addStaff(const StaffUserModel(
        id: 'STAFF-01',
        name: 'Andi Wijaya',
        role: 'Cashier',
      ));
      controller.addStaff(const StaffUserModel(
        id: 'STAFF-02',
        name: 'Budi',
        role: 'Kitchen',
      ));

      expect(controller.search('andi'), hasLength(1));
      expect(controller.search('staff-02'), hasLength(1));
      expect(controller.search('KITCHEN'), hasLength(1));
      expect(controller.search(''), hasLength(2));
    });

    test('removes staff and returns read-only collections', () {
      final controller = StaffManagementController();
      controller.addStaff(const StaffUserModel(
        id: 'STAFF-01',
        name: 'Andi',
        role: 'Cashier',
      ));

      expect(controller.removeStaff('STAFF-01'), isTrue);
      expect(controller.removeStaff('STAFF-01'), isFalse);
      expect(controller.findById('STAFF-01'), isNull);
      expect(
        () => controller.staff.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
