import 'package:flutter/material.dart';

import '../../classes/school_class_repository.dart';
import '../../students/student_repository.dart';
import 'new_admission_page.dart';

class StudentEditPage extends StatelessWidget {
  const StudentEditPage({
    super.key,
    required this.repo,
    required this.classRepo,
    required this.studentId,
    required this.onBack,
    required this.onSaved,
  });

  final StudentRepository repo;
  final SchoolClassRepository classRepo;
  final String studentId;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Student?>(
      stream: repo.watchStudent(studentId),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final s = snap.data;
        if (s == null) return const Center(child: Text('Student not found.'));

        return StudentFormPage(
          mode: StudentFormMode.edit,
          repo: repo,
          classRepo: classRepo,
          studentId: s.id,
          initial: StudentDraft(
            admissionId: s.admissionId,
            fullName: s.fullName,
            email: s.email,
            dateOfBirth: s.dateOfBirth,
            gender: s.gender,
            nationality: s.nationality,
            languagesSpoken: s.languagesSpoken,
            medium: s.medium.isEmpty ? 'English' : s.medium,
            schoolClassCode: s.schoolClassCode,
            className: s.className,
            section: s.section,
            rollNo: s.rollNo,
            enrollmentStatus: s.enrollmentStatus,
            admissionYear: s.admissionYear,
            previousInstitution: s.previousInstitution,
            lastGradeCompleted: s.lastGradeCompleted,
            guardianName: s.guardianName,
            guardianRelation: s.guardianRelation.isEmpty ? 'Mother' : s.guardianRelation,
            guardianEmail: s.guardianEmail,
            phone: s.phone,
            address: s.address,
            medicalNotes: s.medicalNotes,
            annualFeeDue: s.annualFeeDue,
          ),
          onBack: onBack,
          onSaved: onSaved,
        );
      },
    );
  }
}

