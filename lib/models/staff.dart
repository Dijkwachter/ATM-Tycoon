import '../core/constants.dart';
import 'enums.dart';

/// Een medewerker die eenmalig in dienst genomen kan worden. Immutable.
///
/// Regels: GDD 7.2 tabel Medewerkers.
class Staff {
  const Staff({required this.id, this.hired = false});

  final StaffId id;
  final bool hired;

  double get price => switch (id) {
    StaffId.mechanic => kStaffMechanicPrice,
    StaffId.citPlanner => kStaffCitPlannerPrice,
    StaffId.analyst => kStaffAnalystPrice,
    StaffId.regionalManager => kStaffRegionalManagerPrice,
  };

  Staff copyWith({bool? hired}) => Staff(id: id, hired: hired ?? this.hired);
}
