import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Main platform title
  ///
  /// In en, this message translates to:
  /// **'Smart Education Platform'**
  String get appTitle;

  /// Splash subtitle
  ///
  /// In en, this message translates to:
  /// **'Advanced Education Platform'**
  String get advancedMathEducationPlatform;

  /// Generic loading state
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get errorOccurred;

  /// Retry action button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Empty state label
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get emptyData;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Search placeholder or button
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Filter button
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// All filter option
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Actions column or header
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// More options label
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Drawer tooltip
  ///
  /// In en, this message translates to:
  /// **'All Screens & Sections'**
  String get allScreensAndSections;

  /// Success message title
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// Warning message title
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// Info message title
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get info;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Time label
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Duration label
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// Minutes label
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// Questions count label
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questions;

  /// Total label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Details label
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// Logout button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get logout;

  /// Switch language action
  ///
  /// In en, this message translates to:
  /// **'Switch Language'**
  String get switchLanguage;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Arabic language name
  ///
  /// In en, this message translates to:
  /// **'Ø§Ù„Ø¹Ø±Ø¨ÙŠØ©'**
  String get arabic;

  /// Select button or prompt
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// Submit button
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// View action
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Refresh action
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Search empty state
  ///
  /// In en, this message translates to:
  /// **'No matching results found'**
  String get noResultsFound;

  /// Feature coming soon note
  ///
  /// In en, this message translates to:
  /// **'Feature under development'**
  String get underDevelopment;

  /// Active status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Inactive status
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// Pending status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Suspended status
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get suspended;

  /// Rejected status
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// Not available abbreviation
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// Copy action
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// Copied toast
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copied;

  /// Download action
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// Upload action
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// Login screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Access your learning workspace'**
  String get loginSubtitle;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailLabel;

  /// Email hint
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Password hint
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// Signing in progress text
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get loggingIn;

  /// Invalid credentials error
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Teacher role
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleTeacher;

  /// Student role
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleStudent;

  /// Parent role
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// Role selector label
  ///
  /// In en, this message translates to:
  /// **'Select Role'**
  String get selectRole;

  /// Student registration title
  ///
  /// In en, this message translates to:
  /// **'Student Registration'**
  String get registerStudentTitle;

  /// Student registration subtitle
  ///
  /// In en, this message translates to:
  /// **'Create your account to join your teacher\'s study groups'**
  String get registerStudentSubtitle;

  /// Full name field
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// Full name hint
  ///
  /// In en, this message translates to:
  /// **'Enter student full name'**
  String get fullNameHint;

  /// Phone field label
  ///
  /// In en, this message translates to:
  /// **'Student Phone Number'**
  String get phoneLabel;

  /// Phone hint
  ///
  /// In en, this message translates to:
  /// **'01xxxxxxxxx'**
  String get phoneHint;

  /// Parent phone label
  ///
  /// In en, this message translates to:
  /// **'Parent Phone'**
  String get parentPhoneLabel;

  /// Parent phone hint
  ///
  /// In en, this message translates to:
  /// **'01xxxxxxxxx'**
  String get parentPhoneHint;

  /// Target exam field
  ///
  /// In en, this message translates to:
  /// **'Target Exam'**
  String get targetExamLabel;

  /// Target exam dropdown prompt
  ///
  /// In en, this message translates to:
  /// **'Select target standardized exam'**
  String get selectTargetExam;

  /// Register button
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerSubmitButton;

  /// Register progress
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get registeringStudent;

  /// Success title
  ///
  /// In en, this message translates to:
  /// **'Registration Submitted'**
  String get registrationSuccessTitle;

  /// Success message
  ///
  /// In en, this message translates to:
  /// **'Your account request was submitted. Awaiting teacher review and approval.'**
  String get registrationSuccessBody;

  /// Already registered link
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccount;

  /// No account link
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register as a student'**
  String get dontHaveAccount;

  /// Pending approval title
  ///
  /// In en, this message translates to:
  /// **'Account Pending Approval'**
  String get studentPendingTitle;

  /// Pending approval subtitle
  ///
  /// In en, this message translates to:
  /// **'Your application has been received'**
  String get studentPendingSubtitle;

  /// Pending approval description
  ///
  /// In en, this message translates to:
  /// **'Your registration request is currently under review by the teacher. You will gain full platform access once approved.'**
  String get studentPendingDescription;

  /// Check pending status button
  ///
  /// In en, this message translates to:
  /// **'Check Status'**
  String get checkStatusButton;

  /// Tenant suspended title
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get tenantSuspendedTitle;

  /// Tenant suspended message
  ///
  /// In en, this message translates to:
  /// **'This institutional workspace is currently suspended. Please contact platform administration.'**
  String get tenantSuspendedMessage;

  /// Tenant suspended help note
  ///
  /// In en, this message translates to:
  /// **'If you believe this is in error, please reach out to your instructor or support team.'**
  String get tenantSuspendedHelp;

  /// Onboarding title
  ///
  /// In en, this message translates to:
  /// **'Platform Provisioning'**
  String get platformOnboardingTitle;

  /// Create tenant heading
  ///
  /// In en, this message translates to:
  /// **'Provision New Teacher Workspace'**
  String get createTenantTitle;

  /// Tenant name label
  ///
  /// In en, this message translates to:
  /// **'Platform / Academy Name'**
  String get tenantNameLabel;

  /// Tenant name hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Newton Academy'**
  String get tenantNameHint;

  /// Subdomain label
  ///
  /// In en, this message translates to:
  /// **'Workspace Subdomain'**
  String get tenantSubdomainLabel;

  /// Subdomain hint
  ///
  /// In en, this message translates to:
  /// **'e.g. newton-academy'**
  String get tenantSubdomainHint;

  /// Lead teacher name
  ///
  /// In en, this message translates to:
  /// **'Lead Teacher Name'**
  String get teacherNameLabel;

  /// Lead teacher name hint
  ///
  /// In en, this message translates to:
  /// **'Dr. Full Name'**
  String get teacherNameHint;

  /// Admin email label
  ///
  /// In en, this message translates to:
  /// **'Teacher Account Email'**
  String get adminEmailLabel;

  /// Admin email hint
  ///
  /// In en, this message translates to:
  /// **'teacher@domain.com'**
  String get adminEmailHint;

  /// Provision button
  ///
  /// In en, this message translates to:
  /// **'Provision Workspace'**
  String get createTenantButton;

  /// Provision progress
  ///
  /// In en, this message translates to:
  /// **'Provisioning workspace...'**
  String get creatingTenant;

  /// Provision success
  ///
  /// In en, this message translates to:
  /// **'Workspace provisioned successfully!'**
  String get tenantCreatedSuccess;

  /// Navigation dashboard
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// Navigation students
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get navStudents;

  /// Navigation groups
  ///
  /// In en, this message translates to:
  /// **'Study Groups'**
  String get navGroups;

  /// Navigation content library
  ///
  /// In en, this message translates to:
  /// **'Content Library'**
  String get navContent;

  /// Navigation assignments
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get navAssignments;

  /// Navigation exams
  ///
  /// In en, this message translates to:
  /// **'Exams & Tests'**
  String get navExams;

  /// Navigation attendance
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get navAttendance;

  /// Navigation notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// Navigation videos
  ///
  /// In en, this message translates to:
  /// **'Video Library'**
  String get navVideos;

  /// Navigation reports
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navReports;

  /// Navigation settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Sidebar section students
  ///
  /// In en, this message translates to:
  /// **'Student Management'**
  String get navSectionStudents;

  /// Sidebar section academic
  ///
  /// In en, this message translates to:
  /// **'Academic Engine'**
  String get navSectionAcademic;

  /// Sidebar section system
  ///
  /// In en, this message translates to:
  /// **'System & Tools'**
  String get navSectionSystem;

  /// Teacher portal header
  ///
  /// In en, this message translates to:
  /// **'Teacher Operations Hub'**
  String get teacherPortal;

  /// Student portal header
  ///
  /// In en, this message translates to:
  /// **'Student Learning Portal'**
  String get studentPortal;

  /// Academic mathematics subtitle
  ///
  /// In en, this message translates to:
  /// **'Academic Platform'**
  String get academicMathematics;

  /// Select study group title
  ///
  /// In en, this message translates to:
  /// **'Select Study Group'**
  String get selectSubjectGroup;

  /// Notice when no groups exist
  ///
  /// In en, this message translates to:
  /// **'Please create a study group first to access {feature}'**
  String createGroupFirstNotice(String feature);

  /// Create group button
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroup;

  /// Select group header with feature name
  ///
  /// In en, this message translates to:
  /// **'Select Group â€¢ {feature}'**
  String selectGroupForFeature(String feature);

  /// Send announcement nav label
  ///
  /// In en, this message translates to:
  /// **'Broadcast Announcement'**
  String get sendAnnouncementNav;

  /// Logout dialog title
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get logoutDialogTitle;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end your active session?'**
  String get logoutDialogContent;

  /// Student bottom nav home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get studentNavDashboard;

  /// Student bottom nav notifications
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get studentNavNotifications;

  /// Student bottom nav materials
  ///
  /// In en, this message translates to:
  /// **'Study Materials'**
  String get studentNavContent;

  /// Student bottom nav assignments
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get studentNavAssignments;

  /// Student bottom nav exams
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get studentNavExams;

  /// Student bottom nav attendance
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get studentNavAttendance;

  /// No groups warning
  ///
  /// In en, this message translates to:
  /// **'You are not enrolled in any study group yet. Please contact your instructor.'**
  String get studentNoGroupsAssigned;

  /// Group selector title
  ///
  /// In en, this message translates to:
  /// **'Select Study Group'**
  String get studentSelectGroup;

  /// Switch group button
  ///
  /// In en, this message translates to:
  /// **'Switch Group'**
  String get studentChangeGroup;

  /// Bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Choose a Study Group to view its materials'**
  String get studentGroupsBottomSheetTitle;

  /// Teacher dashboard title
  ///
  /// In en, this message translates to:
  /// **'Teacher Operations Hub'**
  String get teacherDashboardTitle;

  /// Action radar title
  ///
  /// In en, this message translates to:
  /// **'Teacher Action Radar'**
  String get teacherActionRadarTitle;

  /// Action radar subtitle
  ///
  /// In en, this message translates to:
  /// **'Priority pending operations requiring your review'**
  String get teacherActionRadarSubtitle;

  /// Pending students count badge
  ///
  /// In en, this message translates to:
  /// **'{count} Students Pending Approval'**
  String pendingApprovalsCount(int count);

  /// Attendance card title
  ///
  /// In en, this message translates to:
  /// **'Attendance Records'**
  String get attendanceReviewTitle;

  /// Attendance card subtitle
  ///
  /// In en, this message translates to:
  /// **'Track and record daily group attendance'**
  String get attendanceReviewSubtitle;

  /// Grading queue card title
  ///
  /// In en, this message translates to:
  /// **'Assignments Requiring Grading'**
  String get gradingQueueTitle;

  /// Grading queue subtitle
  ///
  /// In en, this message translates to:
  /// **'Student submissions awaiting assessment'**
  String get gradingQueueSubtitle;

  /// Activity card title
  ///
  /// In en, this message translates to:
  /// **'Recent Platform Activity'**
  String get recentActivityTitle;

  /// Quick stats title
  ///
  /// In en, this message translates to:
  /// **'Academic Overview'**
  String get quickStatsTitle;

  /// Active students stat
  ///
  /// In en, this message translates to:
  /// **'Active Students'**
  String get activeStudentsCount;

  /// Total groups stat
  ///
  /// In en, this message translates to:
  /// **'Active Study Groups'**
  String get totalGroupsCount;

  /// Scheduled exams stat
  ///
  /// In en, this message translates to:
  /// **'Active Exams'**
  String get scheduledExamsCount;

  /// Materials stat
  ///
  /// In en, this message translates to:
  /// **'Published Materials'**
  String get publishedMaterialsCount;

  /// Student dashboard title
  ///
  /// In en, this message translates to:
  /// **'Student Learning Dashboard'**
  String get studentDashboardTitle;

  /// Student greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String studentWelcomeGreeting(String name);

  /// SAT mastery card title
  ///
  /// In en, this message translates to:
  /// **'SAT Domain Mastery'**
  String get satMasteryTitle;

  /// SAT projected score title
  ///
  /// In en, this message translates to:
  /// **'SAT Projected Score'**
  String get satScoreProjection;

  /// Domain label
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get satMathDomain;

  /// SAT math domain 1
  ///
  /// In en, this message translates to:
  /// **'Heart of Algebra'**
  String get heartOfAlgebra;

  /// SAT math domain 2
  ///
  /// In en, this message translates to:
  /// **'Problem Solving & Data Analysis'**
  String get problemSolvingDataAnalysis;

  /// SAT math domain 3
  ///
  /// In en, this message translates to:
  /// **'Passport to Advanced Topics'**
  String get passportToAdvancedMath;

  /// SAT math domain 4
  ///
  /// In en, this message translates to:
  /// **'Additional Topics'**
  String get additionalTopicsMath;

  /// Upcoming exams title
  ///
  /// In en, this message translates to:
  /// **'Upcoming Tests & Quizzes'**
  String get upcomingExamsTitle;

  /// Recent assignments title
  ///
  /// In en, this message translates to:
  /// **'Pending Assignments'**
  String get recentAssignmentsTitle;

  /// Continue learning button
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continueLearning;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'Parent Portal'**
  String get parentDashboardTitle;

  /// Child selector dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Student'**
  String get parentSelectChild;

  /// Academic overview card title
  ///
  /// In en, this message translates to:
  /// **'Academic Performance Overview'**
  String get academicOverviewTitle;

  /// Attendance rate stat
  ///
  /// In en, this message translates to:
  /// **'Attendance Rate'**
  String get childAttendanceRate;

  /// Exam average stat
  ///
  /// In en, this message translates to:
  /// **'Exam Score Average'**
  String get childExamAverage;

  /// Pending assignments stat
  ///
  /// In en, this message translates to:
  /// **'Pending Assignments'**
  String get childPendingAssignments;

  /// Child activity title
  ///
  /// In en, this message translates to:
  /// **'Child\'s Recent Activity'**
  String get childRecentActivity;

  /// Call instructor button
  ///
  /// In en, this message translates to:
  /// **'Call Instructor'**
  String get callTeacherAction;

  /// Message instructor button
  ///
  /// In en, this message translates to:
  /// **'Contact Instructor'**
  String get messageTeacherAction;

  /// Students list title
  ///
  /// In en, this message translates to:
  /// **'Student Directory'**
  String get studentsListTitle;

  /// Student search hint
  ///
  /// In en, this message translates to:
  /// **'Search by student name or phone...'**
  String get searchStudentsHint;

  /// All groups filter
  ///
  /// In en, this message translates to:
  /// **'All Study Groups'**
  String get allGroupsFilter;

  /// All statuses filter
  ///
  /// In en, this message translates to:
  /// **'All Statuses'**
  String get allStatusesFilter;

  /// Pending students title
  ///
  /// In en, this message translates to:
  /// **'Pending Student Approvals'**
  String get pendingStudentsTitle;

  /// Pending students count
  ///
  /// In en, this message translates to:
  /// **'{count} pending applications'**
  String pendingStudentsCount(int count);

  /// Approve student button
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveStudentAction;

  /// Reject student button
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectStudentAction;

  /// Approve student modal title
  ///
  /// In en, this message translates to:
  /// **'Approve Student Registration'**
  String get approveStudentConfirmTitle;

  /// Approve student modal body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve {name}? They will gain immediate access to their student portal.'**
  String approveStudentConfirmBody(String name);

  /// Reject student modal title
  ///
  /// In en, this message translates to:
  /// **'Reject Student Registration'**
  String get rejectStudentConfirmTitle;

  /// Reject student modal body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject the application for {name}?'**
  String rejectStudentConfirmBody(String name);

  /// Student approved toast
  ///
  /// In en, this message translates to:
  /// **'Student approved successfully'**
  String get studentApprovedToast;

  /// Student rejected toast
  ///
  /// In en, this message translates to:
  /// **'Student registration rejected'**
  String get studentRejectedToast;

  /// Assign groups button
  ///
  /// In en, this message translates to:
  /// **'Manage Groups'**
  String get assignGroupsAction;

  /// Assign groups page title
  ///
  /// In en, this message translates to:
  /// **'Assign Study Groups'**
  String get assignGroupsTitle;

  /// Assign groups subtitle
  ///
  /// In en, this message translates to:
  /// **'Select groups for {name}'**
  String assignGroupsSubtitle(String name);

  /// Assign groups helper
  ///
  /// In en, this message translates to:
  /// **'Check the groups this student should be enrolled in:'**
  String get selectGroupsInstruction;

  /// Groups saved toast
  ///
  /// In en, this message translates to:
  /// **'Group assignments updated successfully'**
  String get groupsAssignedSuccess;

  /// Student 360 profile title
  ///
  /// In en, this message translates to:
  /// **'Student 360Â° Profile'**
  String get student360Title;

  /// Tab overview
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// Tab exams history
  ///
  /// In en, this message translates to:
  /// **'Exams & Scores'**
  String get tabAcademicHistory;

  /// Tab attendance
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get tabAttendance;

  /// Tab assignments
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get tabAssignments;

  /// Tab parent info
  ///
  /// In en, this message translates to:
  /// **'Parent Contact'**
  String get tabParentContact;

  /// Student phone label
  ///
  /// In en, this message translates to:
  /// **'Student Phone'**
  String get studentPhoneTitle;

  /// Parent phone label
  ///
  /// In en, this message translates to:
  /// **'Parent Phone'**
  String get parentPhoneTitle;

  /// Enrollment date label
  ///
  /// In en, this message translates to:
  /// **'Enrolled Date'**
  String get enrollmentDateTitle;

  /// Enrolled groups label
  ///
  /// In en, this message translates to:
  /// **'Enrolled Groups'**
  String get currentGroupsTitle;

  /// Average exam score
  ///
  /// In en, this message translates to:
  /// **'Average Score'**
  String get overallExamAverage;

  /// Label for attendance percentage
  ///
  /// In en, this message translates to:
  /// **'Attendance Rate'**
  String get attendanceRateLabel;

  /// Groups list title
  ///
  /// In en, this message translates to:
  /// **'Study Groups'**
  String get groupsListTitle;

  /// Create group button
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroupAction;

  /// Group name label
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get groupNameLabel;

  /// Group name hint
  ///
  /// In en, this message translates to:
  /// **'e.g. SAT Basics - Cohort Alpha'**
  String get groupNameHint;

  /// Group description label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get groupDescriptionLabel;

  /// Group grade level
  ///
  /// In en, this message translates to:
  /// **'Academic Level'**
  String get groupGradeLevelLabel;

  /// Target exam label
  ///
  /// In en, this message translates to:
  /// **'Target Exam'**
  String get groupTargetExamLabel;

  /// Capacity label
  ///
  /// In en, this message translates to:
  /// **'Capacity (Students)'**
  String get groupCapacityLabel;

  /// Schedule label
  ///
  /// In en, this message translates to:
  /// **'Meeting Schedule'**
  String get groupScheduleLabel;

  /// Schedule hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Sundays & Tuesdays @ 5:00 PM'**
  String get groupScheduleHint;

  /// Group created toast
  ///
  /// In en, this message translates to:
  /// **'Study group created successfully'**
  String get groupCreatedSuccess;

  /// Group updated toast
  ///
  /// In en, this message translates to:
  /// **'Group details updated'**
  String get groupUpdatedSuccess;

  /// Group delete title
  ///
  /// In en, this message translates to:
  /// **'Delete Study Group'**
  String get groupDeleteConfirmTitle;

  /// Group delete body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this group? All enrolled memberships will be revoked.'**
  String get groupDeleteConfirmBody;

  /// Group members tab
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get groupMembersTab;

  /// Group materials tab
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get groupContentTab;

  /// Group assignments tab
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get groupAssignmentsTab;

  /// Group exams tab
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get groupExamsTab;

  /// Add student to group button
  ///
  /// In en, this message translates to:
  /// **'Add Student'**
  String get addMemberAction;

  /// Remove student button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeMemberAction;

  /// Search group members
  ///
  /// In en, this message translates to:
  /// **'Search group students...'**
  String get searchMembersHint;

  /// Add member modal title
  ///
  /// In en, this message translates to:
  /// **'Add Student to Group'**
  String get addMemberTitle;

  /// Student dropdown prompt
  ///
  /// In en, this message translates to:
  /// **'Select an active student:'**
  String get selectStudentToAdd;

  /// Member added toast
  ///
  /// In en, this message translates to:
  /// **'Student added to group'**
  String get memberAddedSuccess;

  /// Member removed toast
  ///
  /// In en, this message translates to:
  /// **'Student removed from group'**
  String get memberRemovedSuccess;

  /// Empty group members state
  ///
  /// In en, this message translates to:
  /// **'No students enrolled in this group yet.'**
  String get emptyMembersMessage;

  /// Content library title
  ///
  /// In en, this message translates to:
  /// **'Content & Library'**
  String get contentLibraryTitle;

  /// Add content FAB label
  ///
  /// In en, this message translates to:
  /// **'Add Material'**
  String get addContentAction;

  /// Content title label
  ///
  /// In en, this message translates to:
  /// **'Material Title'**
  String get contentTitleLabel;

  /// Content description label
  ///
  /// In en, this message translates to:
  /// **'Summary / Description'**
  String get contentDescriptionLabel;

  /// Content type label
  ///
  /// In en, this message translates to:
  /// **'Content Type'**
  String get contentTypeLabel;

  /// Video type
  ///
  /// In en, this message translates to:
  /// **'Recorded Video'**
  String get contentTypeVideo;

  /// PDF type
  ///
  /// In en, this message translates to:
  /// **'PDF Document'**
  String get contentTypePdf;

  /// Document type
  ///
  /// In en, this message translates to:
  /// **'Worksheet / Notes'**
  String get contentTypeDocument;

  /// Link type
  ///
  /// In en, this message translates to:
  /// **'Web Resource Link'**
  String get contentTypeLink;

  /// URL field
  ///
  /// In en, this message translates to:
  /// **'Resource URL'**
  String get contentUrlLabel;

  /// Downloadable switch
  ///
  /// In en, this message translates to:
  /// **'Allow Offline Download'**
  String get isDownloadableLabel;

  /// Status label
  ///
  /// In en, this message translates to:
  /// **'Publication Status'**
  String get publishStatusLabel;

  /// Draft status
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// Published status
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get statusPublished;

  /// Upload file button
  ///
  /// In en, this message translates to:
  /// **'Select File to Upload'**
  String get uploadFileAction;

  /// Selected file notice
  ///
  /// In en, this message translates to:
  /// **'Selected: {fileName}'**
  String fileSelectedNotice(String fileName);

  /// Content created toast
  ///
  /// In en, this message translates to:
  /// **'Material uploaded and saved successfully'**
  String get contentCreatedSuccess;

  /// Delete content title
  ///
  /// In en, this message translates to:
  /// **'Delete Material'**
  String get deleteContentConfirmTitle;

  /// Delete content body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this educational material?'**
  String get deleteContentConfirmBody;

  /// Material viewer title
  ///
  /// In en, this message translates to:
  /// **'Study Material'**
  String get materialViewerTitle;

  /// Download button
  ///
  /// In en, this message translates to:
  /// **'Download Resource'**
  String get downloadMaterialAction;

  /// Open button
  ///
  /// In en, this message translates to:
  /// **'Open Resource'**
  String get viewMaterialAction;

  /// Access policy note
  ///
  /// In en, this message translates to:
  /// **'Includes access to materials published prior to group enrollment.'**
  String get previousContentNotice;

  /// Assignments list title
  ///
  /// In en, this message translates to:
  /// **'Assignments & Homework'**
  String get assignmentsListTitle;

  /// Create assignment button
  ///
  /// In en, this message translates to:
  /// **'New Assignment'**
  String get createAssignmentAction;

  /// Assignment title label
  ///
  /// In en, this message translates to:
  /// **'Assignment Title'**
  String get assignmentTitleLabel;

  /// Due date label
  ///
  /// In en, this message translates to:
  /// **'Due Date & Time'**
  String get assignmentDueDateLabel;

  /// Max score label
  ///
  /// In en, this message translates to:
  /// **'Maximum Score'**
  String get assignmentMaxScoreLabel;

  /// Instructions label
  ///
  /// In en, this message translates to:
  /// **'Instructions & Requirements'**
  String get assignmentDescriptionLabel;

  /// Assignment created toast
  ///
  /// In en, this message translates to:
  /// **'Assignment published successfully'**
  String get assignmentCreatedSuccess;

  /// Submissions title
  ///
  /// In en, this message translates to:
  /// **'Student Submissions'**
  String get submissionsTitle;

  /// Submission status submitted
  ///
  /// In en, this message translates to:
  /// **'Pending Grading'**
  String get submissionStatusSubmitted;

  /// Not submitted status
  ///
  /// In en, this message translates to:
  /// **'Not Submitted'**
  String get submissionStatusNotSubmitted;

  /// Graded status
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get submissionStatusGraded;

  /// Submit homework button
  ///
  /// In en, this message translates to:
  /// **'Submit Solution'**
  String get submitAssignmentAction;

  /// Submission attachment
  ///
  /// In en, this message translates to:
  /// **'Attach Solution File'**
  String get submissionFileLabel;

  /// Submission notes
  ///
  /// In en, this message translates to:
  /// **'Student Notes (Optional)'**
  String get submissionNotesLabel;

  /// Assignment submitted success message
  ///
  /// In en, this message translates to:
  /// **'Assignment submitted successfully!'**
  String get assignmentSubmittedSuccess;

  /// Grade submission screen title
  ///
  /// In en, this message translates to:
  /// **'Grade Student Submission'**
  String get gradeSubmissionTitle;

  /// Score field
  ///
  /// In en, this message translates to:
  /// **'Score Awarded'**
  String get scoreEarnedLabel;

  /// Feedback field
  ///
  /// In en, this message translates to:
  /// **'Instructor Feedback & Comments'**
  String get teacherFeedbackLabel;

  /// Save grade button
  ///
  /// In en, this message translates to:
  /// **'Record Grade'**
  String get saveGradeAction;

  /// Grade saved toast
  ///
  /// In en, this message translates to:
  /// **'Grade saved successfully'**
  String get gradeSavedSuccess;

  /// Exams list title
  ///
  /// In en, this message translates to:
  /// **'Exams & Quizzes'**
  String get examsListTitle;

  /// Create exam button
  ///
  /// In en, this message translates to:
  /// **'Create Exam'**
  String get createExamAction;

  /// Exam title label
  ///
  /// In en, this message translates to:
  /// **'Exam Title'**
  String get examTitleLabel;

  /// Exam duration label
  ///
  /// In en, this message translates to:
  /// **'Exam Duration'**
  String get examDurationLabel;

  /// Duration in minutes format
  ///
  /// In en, this message translates to:
  /// **'{minutes} mins'**
  String examDurationMinutes(int minutes);

  /// Passing score field
  ///
  /// In en, this message translates to:
  /// **'Passing Score (%)'**
  String get examPassingScoreLabel;

  /// Guidelines label
  ///
  /// In en, this message translates to:
  /// **'Exam Guidelines'**
  String get examInstructionsLabel;

  /// Assigned group
  ///
  /// In en, this message translates to:
  /// **'Assigned Study Group'**
  String get examTargetGroupLabel;

  /// Questions count badge
  ///
  /// In en, this message translates to:
  /// **'{count} Questions'**
  String questionsCountLabel(int count);

  /// Add question action button
  ///
  /// In en, this message translates to:
  /// **'Add Quiz Question'**
  String get addQuestionAction;

  /// Question text field
  ///
  /// In en, this message translates to:
  /// **'Question Text'**
  String get questionTextLabel;

  /// Points field
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get questionPointsLabel;

  /// Option label
  ///
  /// In en, this message translates to:
  /// **'Option {letter}'**
  String optionTextLabel(String letter);

  /// Correct checkbox
  ///
  /// In en, this message translates to:
  /// **'Mark as Correct Answer'**
  String get markAsCorrectOption;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Each question must have at least one correct answer option.'**
  String get atLeastOneCorrectWarning;

  /// Exam created toast
  ///
  /// In en, this message translates to:
  /// **'Exam created and scheduled successfully'**
  String get examCreatedSuccess;

  /// Student exams title
  ///
  /// In en, this message translates to:
  /// **'Standardized Tests & Quizzes'**
  String get studentExamsTitle;

  /// Available exams heading
  ///
  /// In en, this message translates to:
  /// **'Available Exams'**
  String get availableExamsTitle;

  /// Completed exams heading
  ///
  /// In en, this message translates to:
  /// **'Completed Exams'**
  String get completedExamsTitle;

  /// Start exam button
  ///
  /// In en, this message translates to:
  /// **'Take Exam'**
  String get startExamAction;

  /// Exam intro title
  ///
  /// In en, this message translates to:
  /// **'Exam Overview & Guidelines'**
  String get examIntroTitle;

  /// Exam immutable rule
  ///
  /// In en, this message translates to:
  /// **'Once an exam session is submitted, responses become immutable and cannot be re-taken.'**
  String get examImmutabilityWarning;

  /// Exam duration info
  ///
  /// In en, this message translates to:
  /// **'Total Time Limit: {duration} minutes'**
  String examDurationInfo(int duration);

  /// Exam questions info
  ///
  /// In en, this message translates to:
  /// **'Total Questions: {count}'**
  String examTotalQuestionsInfo(int count);

  /// Begin exam button
  ///
  /// In en, this message translates to:
  /// **'Begin Exam Session'**
  String get beginExamButton;

  /// Active exam title
  ///
  /// In en, this message translates to:
  /// **'Active Exam Session'**
  String get examTakingTitle;

  /// Time left timer label
  ///
  /// In en, this message translates to:
  /// **'Time Left'**
  String get timeRemainingLabel;

  /// Question progress
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionProgressLabel(int current, int total);

  /// Previous question button
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousQuestionAction;

  /// Next question button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextQuestionAction;

  /// Flag button
  ///
  /// In en, this message translates to:
  /// **'Flag for Review'**
  String get flagQuestionAction;

  /// Unflag button
  ///
  /// In en, this message translates to:
  /// **'Remove Flag'**
  String get unflagQuestionAction;

  /// Submit exam button
  ///
  /// In en, this message translates to:
  /// **'Submit Exam'**
  String get reviewSubmitAction;

  /// Submit modal title
  ///
  /// In en, this message translates to:
  /// **'Submit Exam Final Responses'**
  String get submitExamDialogTitle;

  /// Submit modal body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to finish and submit your exam? All responses will be graded atomically.'**
  String get submitExamDialogBody;

  /// Submitting progress
  ///
  /// In en, this message translates to:
  /// **'Submitting exam...'**
  String get submittingExam;

  /// Exam submitted toast
  ///
  /// In en, this message translates to:
  /// **'Exam submitted and graded successfully!'**
  String get examSubmittedSuccess;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Exam & Test Results (P-05)'**
  String get examResultsTitle;

  /// Score label
  ///
  /// In en, this message translates to:
  /// **'Score Achieved'**
  String get examScoreLabel;

  /// Percentage label
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get examPercentageLabel;

  /// Passed badge
  ///
  /// In en, this message translates to:
  /// **'PASSED'**
  String get examPassedStatus;

  /// Failed badge
  ///
  /// In en, this message translates to:
  /// **'NEEDS IMPROVEMENT'**
  String get examFailedStatus;

  /// Return button
  ///
  /// In en, this message translates to:
  /// **'Return to Exams'**
  String get backToExamsAction;

  /// SAT tools sheet title
  ///
  /// In en, this message translates to:
  /// **'SAT Reference Tools'**
  String get satToolsTitle;

  /// Calculator tool
  ///
  /// In en, this message translates to:
  /// **'Desmos Scientific Calculator'**
  String get satDesmosCalculator;

  /// Reference sheet tool
  ///
  /// In en, this message translates to:
  /// **'SAT Reference Formulas'**
  String get satReferenceSheet;

  /// Formula sheet subtitle
  ///
  /// In en, this message translates to:
  /// **'Area, Volume & Special Right Triangles (30-60-90 & 45-45-90)'**
  String get satFormulaSheet;

  /// SAT timer label
  ///
  /// In en, this message translates to:
  /// **'Timer Running'**
  String get satCountdownTimer;

  /// Attendance title
  ///
  /// In en, this message translates to:
  /// **'Lecture Attendance'**
  String get attendanceTitle;

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDateLabel;

  /// Mark all present button
  ///
  /// In en, this message translates to:
  /// **'Mark All Present'**
  String get markAllPresentAction;

  /// Save attendance sheet button
  ///
  /// In en, this message translates to:
  /// **'Save Attendance Sheet'**
  String get saveAttendanceAction;

  /// Attendance saved success snackbar
  ///
  /// In en, this message translates to:
  /// **'Attendance sheet saved successfully'**
  String get attendanceSavedSuccess;

  /// Attendance status present
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get statusPresent;

  /// Attendance status absent
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get statusAbsent;

  /// Attendance status late
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get statusLate;

  /// Attendance status excused
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get statusExcused;

  /// Attendance summary heading
  ///
  /// In en, this message translates to:
  /// **'Attendance Summary'**
  String get attendanceSummaryTitle;

  /// Present count
  ///
  /// In en, this message translates to:
  /// **'{count} Present'**
  String presentCountLabel(int count);

  /// Absent count
  ///
  /// In en, this message translates to:
  /// **'{count} Absent'**
  String absentCountLabel(int count);

  /// Student attendance title
  ///
  /// In en, this message translates to:
  /// **'My Attendance Record'**
  String get studentAttendanceTitle;

  /// Student attendance history
  ///
  /// In en, this message translates to:
  /// **'Recorded Sessions History'**
  String get studentAttendanceHistory;

  /// Video player title
  ///
  /// In en, this message translates to:
  /// **'Lecture Video Player'**
  String get videoPlayerTitle;

  /// Video upload modal title
  ///
  /// In en, this message translates to:
  /// **'Upload Lecture Video'**
  String get videoUploadTitle;

  /// Video title field
  ///
  /// In en, this message translates to:
  /// **'Video Title'**
  String get videoTitleLabel;

  /// Choose video button
  ///
  /// In en, this message translates to:
  /// **'Choose Video File (MP4, MOV)'**
  String get selectVideoFileAction;

  /// Upload notice
  ///
  /// In en, this message translates to:
  /// **'Uploading video to Bunny Stream...'**
  String get uploadingVideoNotice;

  /// Processing notice
  ///
  /// In en, this message translates to:
  /// **'Transcoding & encoding multi-resolution stream...'**
  String get processingVideoNotice;

  /// Video ready
  ///
  /// In en, this message translates to:
  /// **'Ready for Streaming'**
  String get videoReadyStatus;

  /// Video failed
  ///
  /// In en, this message translates to:
  /// **'Video Processing Failed'**
  String get videoFailedStatus;

  /// Playback speed
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get playbackSpeedLabel;

  /// Quality auto
  ///
  /// In en, this message translates to:
  /// **'Auto (HLS adaptive)'**
  String get qualityAuto;

  /// Buffering text
  ///
  /// In en, this message translates to:
  /// **'Buffering high quality video stream...'**
  String get bufferingNotice;

  /// Resume video question
  ///
  /// In en, this message translates to:
  /// **'Resume from previous position at {timestamp}?'**
  String resumeVideoPrompt(String timestamp);

  /// Resume video button
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeVideoAction;

  /// Start over button
  ///
  /// In en, this message translates to:
  /// **'Start from Beginning'**
  String get startOverAction;

  /// Notifications page title
  ///
  /// In en, this message translates to:
  /// **'Notifications Center'**
  String get notificationsCenterTitle;

  /// Mark all read button
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get markAllReadAction;

  /// Empty notifications title
  ///
  /// In en, this message translates to:
  /// **'All caught up!'**
  String get noNotificationsTitle;

  /// Empty notifications body
  ///
  /// In en, this message translates to:
  /// **'You have no unread notifications or announcements at this time.'**
  String get noNotificationsBody;

  /// Page title
  ///
  /// In en, this message translates to:
  /// **'Send Announcement & Alert'**
  String get sendAnnouncementTitle;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Announcement Title'**
  String get announcementTitleLabel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Announcement Content'**
  String get announcementBodyLabel;

  /// Dropdown label
  ///
  /// In en, this message translates to:
  /// **'Target Audience'**
  String get targetAudienceLabel;

  /// All students audience
  ///
  /// In en, this message translates to:
  /// **'All Enrolled Students'**
  String get audienceAllStudents;

  /// Group audience
  ///
  /// In en, this message translates to:
  /// **'Specific Study Group'**
  String get audienceSpecificGroup;

  /// Broadcast button
  ///
  /// In en, this message translates to:
  /// **'Broadcast Message'**
  String get sendAnnouncementAction;

  /// Toast message
  ///
  /// In en, this message translates to:
  /// **'Announcement sent successfully'**
  String get announcementSentSuccess;

  /// New notification alert
  ///
  /// In en, this message translates to:
  /// **'New notification received'**
  String get newNotificationToast;

  /// Custom track label
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customTrack;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'e.g. AP Calculus, Olympiad...'**
  String get customTrackHint;

  /// Target academic track label
  ///
  /// In en, this message translates to:
  /// **'Target Academic Track:'**
  String get targetAcademicTrack;

  /// Registration badge
  ///
  /// In en, this message translates to:
  /// **'Enroll in New Academic Cohort'**
  String get studentRegistrationBadge;

  /// Full name input hint
  ///
  /// In en, this message translates to:
  /// **'Full Name (as on student ID)'**
  String get fullNameInputHint;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter student name'**
  String get pleaseEnterFullName;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter at least first and last name'**
  String get pleaseEnterValidFullName;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get pleaseEnterValidEmail;

  /// Phone label
  ///
  /// In en, this message translates to:
  /// **'Phone Number (Student WhatsApp)'**
  String get studentWhatsappPhone;

  /// Parent phone label
  ///
  /// In en, this message translates to:
  /// **'Parent WhatsApp Number (Reports & Follow-up)'**
  String get parentWhatsappPhone;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter parent WhatsApp phone number'**
  String get pleaseEnterParentPhone;

  /// Student phone label
  ///
  /// In en, this message translates to:
  /// **'Student Phone'**
  String get studentPhoneLabel;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number (at least 10 digits)'**
  String get pleaseEnterValidPhone;

  /// Password hint
  ///
  /// In en, this message translates to:
  /// **'Password (at least 6 characters)'**
  String get passwordFieldHint;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter password (at least 6 characters)'**
  String get pleaseEnterPasswordMin;

  /// Register button
  ///
  /// In en, this message translates to:
  /// **'Create Account & Start Learning â†’'**
  String get registerAndStartLearning;

  /// Already registered prompt
  ///
  /// In en, this message translates to:
  /// **'Already registered?'**
  String get alreadyRegisteredPrompt;

  /// Sign in link
  ///
  /// In en, this message translates to:
  /// **'Sign In Now â†’'**
  String get signInNowLink;

  /// Notice
  ///
  /// In en, this message translates to:
  /// **'Your application will be reviewed and approved by the teacher upon submission'**
  String get registrationApprovalNotice;

  /// New student prompt
  ///
  /// In en, this message translates to:
  /// **'New student to the cohort?'**
  String get newStudentCohortPrompt;

  /// Register link
  ///
  /// In en, this message translates to:
  /// **'Register as New Student Now â†’'**
  String get registerNewStudentLink;

  /// Security note
  ///
  /// In en, this message translates to:
  /// **'Encrypted & secure academic platform for cohort students'**
  String get secureAcademicEncrypted;

  /// Back to home button
  ///
  /// In en, this message translates to:
  /// **'Return to Home'**
  String get backToHome;

  /// Back to login button
  ///
  /// In en, this message translates to:
  /// **'Return to Sign In'**
  String get backToLogin;

  /// Dear student fallback
  ///
  /// In en, this message translates to:
  /// **'Dear Student'**
  String get dearStudent;

  /// Student pending approval greeting
  ///
  /// In en, this message translates to:
  /// **'Hello {name}, your registration details have been received at {brandName}.\nYour account is pending review by {teacherName} to assign you to your designated study group ({track}).'**
  String studentPendingGreeting(
    String name,
    String brandName,
    String teacherName,
    String track,
  );

  /// Platform onboarding title
  ///
  /// In en, this message translates to:
  /// **'Provision New Educational Center'**
  String get provisionNewCenter;

  /// Success banner
  ///
  /// In en, this message translates to:
  /// **'Educational center and teacher account provisioned successfully!'**
  String get centerProvisionedSuccess;

  /// Header
  ///
  /// In en, this message translates to:
  /// **'Center & Institution Information (Tenant)'**
  String get centerDataHeader;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Center or Academy Name *'**
  String get centerNameRequired;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'Please enter center name'**
  String get centerNameRequiredError;

  /// Optional email
  ///
  /// In en, this message translates to:
  /// **'Center Email (Optional)'**
  String get centerEmailOptional;

  /// Optional phone
  ///
  /// In en, this message translates to:
  /// **'Center Phone Number (Optional)'**
  String get centerPhoneOptional;

  /// Optional logo
  ///
  /// In en, this message translates to:
  /// **'Logo URL (Optional)'**
  String get centerLogoUrlOptional;

  /// Header
  ///
  /// In en, this message translates to:
  /// **'Lead Teacher Account Information'**
  String get leadTeacherDataHeader;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Teacher Full Name *'**
  String get leadTeacherNameRequired;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'Please enter teacher name'**
  String get leadTeacherNameRequiredError;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Login Email *'**
  String get leadTeacherEmailRequired;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'Please enter email address'**
  String get leadTeacherEmailRequiredError;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Password *'**
  String get leadTeacherPasswordRequired;

  /// Error
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get leadTeacherPasswordRequiredError;

  /// Optional phone
  ///
  /// In en, this message translates to:
  /// **'Teacher Phone (Optional)'**
  String get leadTeacherPhoneOptional;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Provision Educational Center'**
  String get createAndProvisionCenter;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Proceed to Teacher Sign In'**
  String get goToTeacherLogin;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Provision Another Center'**
  String get provisionAnotherCenter;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Center Name:'**
  String get centerNameLabel2;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Tenant ID:'**
  String get tenantIdLabel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Lead Teacher:'**
  String get leadTeacherLabel;

  /// No description provided for @activeAndReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Active & Ready'**
  String get activeAndReadyStatus;

  /// Radar no delays
  ///
  /// In en, this message translates to:
  /// **'Great! No delays currently in this item ðŸŽ‰'**
  String get radarNoDelays;

  /// Radar title
  ///
  /// In en, this message translates to:
  /// **'Instant Monitoring & Rapid Intervention Radar'**
  String get radarInstantTitle;

  /// Radar subtitle
  ///
  /// In en, this message translates to:
  /// **'Real-time tracking of lecture views, drill submissions, and exam scores'**
  String get radarInstantSubtitle;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Lecture Views'**
  String get radarLectureViewsTitle;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Students incomplete'**
  String get radarLectureViewsSubtitle;

  /// Modal title
  ///
  /// In en, this message translates to:
  /// **'Recent Lecture Watch Time'**
  String get radarLectureModalTitle;

  /// Modal subtitle
  ///
  /// In en, this message translates to:
  /// **'Students who have watched less than 50% of recorded session'**
  String get radarLectureModalSubtitle;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Send Watch Reminder to Students â†’'**
  String get radarSendWatchAlert;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Drill Submissions'**
  String get radarDrillSubmissionsTitle;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Overdue homework'**
  String get radarDrillSubmissionsSubtitle;

  /// Modal title
  ///
  /// In en, this message translates to:
  /// **'Follow up Overdue Drill Homework'**
  String get radarDrillModalTitle;

  /// Modal subtitle
  ///
  /// In en, this message translates to:
  /// **'Students who have not uploaded required screenshot or homework file'**
  String get radarDrillModalSubtitle;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Open Homework & Submissions â†’'**
  String get radarOpenHomeworkList;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Score Alert'**
  String get radarScoreWarningTitle;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Under 600 in exam'**
  String get radarScoreWarningSubtitle;

  /// Modal title
  ///
  /// In en, this message translates to:
  /// **'Academic Score Alert'**
  String get radarScoreModalTitle;

  /// Modal subtitle
  ///
  /// In en, this message translates to:
  /// **'Students who scored low on last quiz requiring extra support'**
  String get radarScoreModalSubtitle;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Review Student Performance & Exams â†’'**
  String get radarReviewPerformance;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Admission Requests'**
  String get radarPendingJoinTitle;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'Students pending approval'**
  String get radarPendingStudentsCount;

  /// Radar card
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get radarNoPendingRequests;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Urgent Alert'**
  String get radarUrgentAlert;

  /// Cohorts section title
  ///
  /// In en, this message translates to:
  /// **'Accredited Test-Prep Cohorts'**
  String get testPrepCohortsTitle;

  /// Cohorts subtitle
  ///
  /// In en, this message translates to:
  /// **'Distribution of students in target 5-student cohorts for SAT / EST / ACT'**
  String get testPrepCohortsSubtitle;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Academic Focus: '**
  String get academicFocusLabel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Average Score: '**
  String get averageScoreLabel;

  /// Chip
  ///
  /// In en, this message translates to:
  /// **'Handouts & PDFs'**
  String get chipHandoutsPdfs;

  /// Chip
  ///
  /// In en, this message translates to:
  /// **'Drill Homework'**
  String get chipDrillHomework;

  /// Chip
  ///
  /// In en, this message translates to:
  /// **'Exams & Simulations'**
  String get chipExamsSimulations;

  /// Chip
  ///
  /// In en, this message translates to:
  /// **'Record Attendance'**
  String get chipRecordAttendance;

  /// Title
  ///
  /// In en, this message translates to:
  /// **'Library & Academic Content'**
  String get libraryAndAcademicContent;

  /// Subtitle
  ///
  /// In en, this message translates to:
  /// **'Select study group to view and manage its materials and files:'**
  String get chooseGroupForLibrary;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Assignments & Submissions'**
  String get assignmentsAndSubmissions;

  /// Subtitle
  ///
  /// In en, this message translates to:
  /// **'Select study group to view assignments and grade students:'**
  String get chooseGroupForAssignments;

  /// Title
  ///
  /// In en, this message translates to:
  /// **'Question Bank & Exams'**
  String get questionBankAndExams;

  /// Subtitle
  ///
  /// In en, this message translates to:
  /// **'Select study group to create and manage interactive exams:'**
  String get chooseGroupForExams;

  /// Title
  ///
  /// In en, this message translates to:
  /// **'Select Group'**
  String get selectGroupModalTitle;

  /// Subtitle
  ///
  /// In en, this message translates to:
  /// **'Choose study group to proceed:'**
  String get selectGroupModalSubtitle;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No study groups created yet.'**
  String get noGroupsCreatedYet;

  /// Description
  ///
  /// In en, this message translates to:
  /// **'A study group must be created first before adding exams and content.'**
  String get mustCreateGroupFirst;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Create New Group Now'**
  String get createNewGroupNow;

  /// Group level
  ///
  /// In en, this message translates to:
  /// **'Level: {level}'**
  String groupLevelLabel(String level);

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Enter â†’'**
  String get enterAction;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of the teacher dashboard?'**
  String get confirmLogoutTeacher;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'{brandName} â€¢ Teacher Operations Hub'**
  String teacherDashboardHeader(String brandName);

  /// Teacher dashboard title (no AppBar)
  ///
  /// In en, this message translates to:
  /// **'Academic Command Center'**
  String get academicDashboardTitle;

  /// Teacher dashboard subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage student groups, track lecture progress, and monitor academic performance across all levels.'**
  String get teacherDashboardSubtitle;

  /// Tap to view placeholder
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get tapToView;

  /// Attendance card subtitle for lecture watch tracking
  ///
  /// In en, this message translates to:
  /// **'Lecture watch tracking analytics'**
  String get lectureWatchingAnalytics;

  /// Hero title
  ///
  /// In en, this message translates to:
  /// **'Welcome to {brandName} • {teacherName}'**
  String welcomeTeacherTitle(String brandName, String teacherName);

  /// Hero subtitle
  ///
  /// In en, this message translates to:
  /// **'Comprehensive tracking for US curriculum students (SAT / EST / ACT), monitoring attendance and lecture views, and analyzing solution speed & accuracy'**
  String get welcomeTeacherSubtitle;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Create New Group'**
  String get createNewGroup;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Send Announcement to Students'**
  String get sendAnnouncementToStudents;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Groups & Students Overview'**
  String get groupsAndStudentsOverview;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'+{count} Pending'**
  String pendingLabel(int count);

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'100% Active'**
  String get allActive;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Total Students'**
  String get totalStudents;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'View Student Lists & Approvals â†’'**
  String get viewStudentsAndApprovals;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Active Groups'**
  String get activeGroups;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Click to Manage & Control â†’'**
  String get clickToManageAndControl;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get excellentStatus;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Cumulative Attendance Rate'**
  String get cumulativeAttendanceRate;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'{count} New'**
  String newNotificationsCount(int count);

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Notifications Center'**
  String get notificationsCenter;

  /// Action
  ///
  /// In en, this message translates to:
  /// **'Student Announcements & Updates â†’'**
  String get studentAnnouncementsAndUpdates;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Academic Platform Services & Sections'**
  String get academicServicesAndSections;

  /// Section subtitle
  ///
  /// In en, this message translates to:
  /// **'Direct instant access to all administrative and academic tools for the instructor'**
  String get directAccessAllTools;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Manage Students & Approvals'**
  String get manageStudentsAndApprovals;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Review registration requests, approve/reject students, and academic profiles'**
  String get manageStudentsDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Manage Study Groups (SAT / EST)'**
  String get manageStudyGroups;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Create new groups, assign tracks, and configure previous content policy'**
  String get manageGroupsDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Daily Attendance Tracking'**
  String get recordDailyAttendance;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Record student attendance/absence in groups and track commitment statistics'**
  String get recordAttendanceDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Send Announcement or Broadcast'**
  String get sendNoticeOrBroadcast;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Publish an announcement to a specific group or all students with instant push notification'**
  String get sendNoticeDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Question Bank & Interactive Exams'**
  String get interactiveExamsBank;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Create and grade online exams, monitor student scores and attempts'**
  String get interactiveExamsDesc;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your student account?'**
  String get confirmLogoutStudent;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'{brandName} â€¢ Student Portal'**
  String studentDashboardHeader(String brandName);

  /// Hero title
  ///
  /// In en, this message translates to:
  /// **'Welcome to {brandName}'**
  String welcomeStudentHeader(String brandName);

  /// Hero subtitle
  ///
  /// In en, this message translates to:
  /// **'Intensive preparation program supervised by {teacherName} to achieve Target 800 in {academicTrack} exams'**
  String studentHeroSubtitle(String teacherName, String academicTrack);

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'American Academy'**
  String get americanMathAcademy;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Academic Track'**
  String get academicTrackLabel;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Assessment System'**
  String get assessmentSystemLabel;

  /// Card desc
  ///
  /// In en, this message translates to:
  /// **'View assigned homework, upload solutions, and track grades'**
  String get studentAssignmentsDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'My Exams & Assessments'**
  String get myExamsAndAssessments;

  /// Card desc
  ///
  /// In en, this message translates to:
  /// **'Take interactive online exams, practice drills, and review grades'**
  String get myExamsAndAssessmentsDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Teacher Announcements & Alerts'**
  String get teacherAnnouncements;

  /// Card desc
  ///
  /// In en, this message translates to:
  /// **'Follow important messages, schedules, and group updates'**
  String get teacherAnnouncementsDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Attendance & Absence Record'**
  String get attendanceRecord;

  /// Card desc
  ///
  /// In en, this message translates to:
  /// **'Track your session attendance rate, commitment record, and dates'**
  String get attendanceRecordDesc;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh Data'**
  String get refreshDashboard;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No students are currently linked to your account.\nPlease provide the teacher with your email address to link your child\'s account.'**
  String get parentNoChildrenLinked;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Refresh Dashboard'**
  String get refreshDashboardButton;

  /// Notice title
  ///
  /// In en, this message translates to:
  /// **'Note for Parents'**
  String get parentNoticeTitle;

  /// Notice desc
  ///
  /// In en, this message translates to:
  /// **'This dashboard is read-only. Exam results and attendance records are updated immediately once approved by the teacher.'**
  String get parentNoticeDesc;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Recent Attendance Sessions (P-06)'**
  String get recentAttendanceSessions;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Last 5 Sessions'**
  String get lastFiveSessions;

  /// Empty
  ///
  /// In en, this message translates to:
  /// **'No attendance records recorded yet'**
  String get noAttendanceRecordsYet;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String noteLabel(String note);

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Approved Results'**
  String get approvedResults;

  /// Empty
  ///
  /// In en, this message translates to:
  /// **'No exam results recorded for this student yet'**
  String get noExamResultsYet;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Submission Date: {date}'**
  String submissionDateLabel(String date);

  /// Domain title
  ///
  /// In en, this message translates to:
  /// **'Heart of Algebra (Linear Equations & Systems)'**
  String get domainAlgebraTitle;

  /// Domain status
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get domainMastered;

  /// Domain title
  ///
  /// In en, this message translates to:
  /// **'Passport to Advanced Topics (Nonlinear & Quadratics)'**
  String get domainAdvancedMathTitle;

  /// Domain status
  ///
  /// In en, this message translates to:
  /// **'Proficient'**
  String get domainProficient;

  /// Domain title
  ///
  /// In en, this message translates to:
  /// **'Problem Solving & Data Analysis (Ratios & Stats)'**
  String get domainDataAnalysisTitle;

  /// Domain status
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get domainInProgress;

  /// Domain title
  ///
  /// In en, this message translates to:
  /// **'Geometry & Trigonometry (Coordinate & Circles)'**
  String get domainGeometryTitle;

  /// Card badge
  ///
  /// In en, this message translates to:
  /// **'SAT Mastery Index (Target 800)'**
  String get satMasteryIndicator;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'SAT Mastery Index & Projected Score (Target 800)'**
  String get satMasteryPredictedScore;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Cumulative performance analysis across 4 College Board domains â€¢ {groupName}'**
  String satMasteryDesc(String groupName);

  /// Mission title
  ///
  /// In en, this message translates to:
  /// **'Your Next Task with {teacherName}:'**
  String nextMissionWithTeacher(String teacherName);

  /// Mission desc
  ///
  /// In en, this message translates to:
  /// **'Drill Homework: Coordinate Geometry & Circles (15 Qs - Screenshot upload)'**
  String get drillHomeworkTitle;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Upload Homework Solution Now â†’'**
  String get uploadHomeworkSolutionNow;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Currently Active Study Groups'**
  String get currentlyActiveStudyGroups;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Add Group'**
  String get addGroup;

  /// Chip
  ///
  /// In en, this message translates to:
  /// **'Content & Handouts'**
  String get chipContentAndHandouts;

  /// Chip
  ///
  /// In en, this message translates to:
  /// **'Group Details â†’'**
  String get groupDetailsAction;

  /// Description
  ///
  /// In en, this message translates to:
  /// **'Upload PDFs, lecture notes, and organize academic content per group'**
  String get uploadPdfHandoutsDesc;

  /// Badge
  ///
  /// In en, this message translates to:
  /// **'Select Group'**
  String get selectGroupBadge;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Homework, Submissions & Grading'**
  String get assignmentsAndGradingTitle;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Assign weekly homework, review solutions, and grade submissions'**
  String get assignmentsAndGradingDesc;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Academy Setup & Tracks Wizard'**
  String get academyOnboardingWizardTitle;

  /// Card subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure instructor and academy profiles, configure American curriculum tracks'**
  String get academyOnboardingWizardDesc;

  /// Assignments chip label
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get assignments;

  /// Exams chip label
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get exams;

  /// Student suspended toast
  ///
  /// In en, this message translates to:
  /// **'Student account suspended'**
  String get studentSuspendedToast;

  /// Student activated toast
  ///
  /// In en, this message translates to:
  /// **'Student account reactivated'**
  String get studentActivatedToast;

  /// Status updated toast
  ///
  /// In en, this message translates to:
  /// **'Status updated'**
  String get statusUpdatedToast;

  /// Suspend title
  ///
  /// In en, this message translates to:
  /// **'Suspend Student Account?'**
  String get suspendStudentConfirmTitle;

  /// Suspend body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to temporarily suspend access for {name}?'**
  String suspendStudentConfirmBody(String name);

  /// Suspend action
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspendStudentAction;

  /// Reactivate title
  ///
  /// In en, this message translates to:
  /// **'Reactivate Student Account?'**
  String get activateStudentConfirmTitle;

  /// Reactivate body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reactivate access for {name}?'**
  String activateStudentConfirmBody(String name);

  /// Reactivate action
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get activateStudentAction;

  /// Pending approval status badge
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get pendingApproval;

  /// Empty search result
  ///
  /// In en, this message translates to:
  /// **'No students matching \"{query}\"'**
  String noStudentsMatchingSearch(String query);

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearch;

  /// Filter empty state
  ///
  /// In en, this message translates to:
  /// **'No students found with this status'**
  String get noStudentsWithStatus;

  /// No students empty state
  ///
  /// In en, this message translates to:
  /// **'No registered students yet'**
  String get noStudentsRegistered;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Back to Students List'**
  String get backToStudentsList;

  /// Page title
  ///
  /// In en, this message translates to:
  /// **'New Registration Requests'**
  String get newRegistrationRequests;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No pending registration requests at this time.\nNew applicants will appear here once submitted.'**
  String get noPendingRegistrationRequests;

  /// Guidance banner
  ///
  /// In en, this message translates to:
  /// **'There are ({count}) registration requests pending approval. Approving a student activates their account, and group assignment is required next.'**
  String pendingGuidanceBanner(int count);

  /// Approve detail
  ///
  /// In en, this message translates to:
  /// **'{name} will be approved and will have platform access once assigned to a study group.'**
  String approveStudentPendingDetail(String name);

  /// Reject detail
  ///
  /// In en, this message translates to:
  /// **'Registration request for {name} will be rejected. The account will not be deleted and can be activated later.'**
  String rejectStudentPendingDetail(String name);

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Request Date: {date}'**
  String requestDateLabel(String date);

  /// Reject button
  ///
  /// In en, this message translates to:
  /// **'Reject Request'**
  String get rejectRequestAction;

  /// Approve button
  ///
  /// In en, this message translates to:
  /// **'Approve & Admit'**
  String get approveAndAdmitAction;

  /// Groups count badge
  ///
  /// In en, this message translates to:
  /// **'{count} Groups'**
  String groupsCountBadge(int count);

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Currently Enrolled Groups'**
  String get currentlyEnrolledGroups;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No groups currently assigned.\nAdd the student to a group below to grant them content access.'**
  String get noAssignedGroupsEmpty;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Available Groups to Enroll'**
  String get availableGroupsToAdd;

  /// Search hint
  ///
  /// In en, this message translates to:
  /// **'Search groups...'**
  String get searchInGroups;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'Student is already enrolled in all available academy groups.'**
  String get studentEnrolledInAllGroups;

  /// Search empty state
  ///
  /// In en, this message translates to:
  /// **'No groups matching \"{query}\"'**
  String noGroupsMatchingQuery(String query);

  /// Modal title
  ///
  /// In en, this message translates to:
  /// **'Assign Study Group?'**
  String get assignGroupConfirmTitle;

  /// Modal body
  ///
  /// In en, this message translates to:
  /// **'Student will be enrolled in \"{groupName}\" and will immediately gain access to materials and assignments according to content policy.'**
  String assignGroupConfirmBody(String groupName);

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Assign Now'**
  String get assignNowAction;

  /// Modal title
  ///
  /// In en, this message translates to:
  /// **'Unassign Study Group?'**
  String get unassignGroupConfirmTitle;

  /// Modal body
  ///
  /// In en, this message translates to:
  /// **'Student will be removed from \"{groupName}\". They will no longer have access to sessions or homework submissions.'**
  String unassignGroupConfirmBody(String groupName);

  /// Date label
  ///
  /// In en, this message translates to:
  /// **'Joined: {date}'**
  String joinedDateLabel(String date);

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Unassign'**
  String get unassignAction;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Assign +'**
  String get assignActionPlus;

  /// Title
  ///
  /// In en, this message translates to:
  /// **'Student Profile'**
  String get studentProfileTitle;

  /// WhatsApp report card title
  ///
  /// In en, this message translates to:
  /// **'Instant Parent WhatsApp Report'**
  String get whatsappParentReportTitle;

  /// WhatsApp report card subtitle
  ///
  /// In en, this message translates to:
  /// **'Generate a professional weekly report ready to send including attendance, views, and exam scores'**
  String get whatsappParentReportSubtitle;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Generate & Share Report'**
  String get createAndShareReport;

  /// Button
  ///
  /// In en, this message translates to:
  /// **'Generate Report'**
  String get createReport;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Performance Statistics'**
  String get statsOverviewTitle;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'Submitted Homework'**
  String get submittedHomeworksLabel;

  /// Stat subtitle
  ///
  /// In en, this message translates to:
  /// **'{count} Reviewed'**
  String reviewedSubtitle(int count);

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'Exam Average'**
  String get examAverageLabel;

  /// Stat label
  ///
  /// In en, this message translates to:
  /// **'Video Completion'**
  String get videoCompletionLabel;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Enrolled Study Groups'**
  String get enrolledStudyGroups;

  /// Empty state
  ///
  /// In en, this message translates to:
  /// **'No study groups assigned to this student yet'**
  String get noGroupsAssignedToStudent;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Last Recorded Activity'**
  String get lastRecordedActivity;

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Account Actions'**
  String get accountActionsTitle;

  /// Tile title
  ///
  /// In en, this message translates to:
  /// **'Suspend Account Temporarily'**
  String get suspendAccountTemporary;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Prevents access without deleting data'**
  String get suspendAccountDesc;

  /// Tile title
  ///
  /// In en, this message translates to:
  /// **'Reactivate Account'**
  String get reactivateAccountTitle;

  /// Tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Restore full platform access'**
  String get reactivateAccountDesc;

  /// Tile title
  ///
  /// In en, this message translates to:
  /// **'Approve & Admit Student'**
  String get approveAndAdmitStudentTitle;

  /// Pill badge
  ///
  /// In en, this message translates to:
  /// **'Previous Content Allowed'**
  String get previousContentAllowedPill;

  /// Pill badge
  ///
  /// In en, this message translates to:
  /// **'New Only'**
  String get newOnlyPill;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Quick Attendance'**
  String get quickAttendanceTooltip;

  /// Filter all chip
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// FAB button
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newGroupButton;

  /// Loading message
  ///
  /// In en, this message translates to:
  /// **'Loading study groups...'**
  String get loadingGroupsList;

  /// Search hint
  ///
  /// In en, this message translates to:
  /// **'Search by group name...'**
  String get searchGroupsHint;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'No study groups created yet'**
  String get noGroupsYet;

  /// Empty state action
  ///
  /// In en, this message translates to:
  /// **'Create First Group'**
  String get createFirstGroup;

  /// Empty filter message
  ///
  /// In en, this message translates to:
  /// **'No groups match your search or filter'**
  String get noGroupsMatchingFilter;

  /// Reset action
  ///
  /// In en, this message translates to:
  /// **'Reset Filters'**
  String get resetFilters;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Add New Study Group'**
  String get createGroupDialogTitle;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter group name'**
  String get groupNameRequired;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Group Track / Level:'**
  String get groupTrackOrLevel;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Custom Track or Category'**
  String get customTrackLabel;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter custom track name'**
  String get customTrackRequired;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Group Description (Optional)'**
  String get groupDescriptionOptional;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Group goals, meeting times, etc...'**
  String get groupDescriptionHint;

  /// Switch label
  ///
  /// In en, this message translates to:
  /// **'Allow Previous Content for New Students'**
  String get allowPreviousContentTitle;

  /// Switch subtitle on
  ///
  /// In en, this message translates to:
  /// **'New students can see content published before joining'**
  String get allowPreviousContentDesc;

  /// Switch subtitle off
  ///
  /// In en, this message translates to:
  /// **'Students only see content published after joining'**
  String get denyPreviousContentDesc;

  /// Snackbar message
  ///
  /// In en, this message translates to:
  /// **'Student added to group successfully'**
  String get studentAddedToGroupSuccess;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Student to Group'**
  String get addStudentToGroupTitle;

  /// Dialog helper text
  ///
  /// In en, this message translates to:
  /// **'Enter student ID to add them directly to this group and enable authorized content access.'**
  String get addStudentToGroupDesc;

  /// Field label
  ///
  /// In en, this message translates to:
  /// **'Student ID (UUID)'**
  String get studentIdLabel;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'e.g. 550e8400-e29b-41d4-a716-446655440000'**
  String get studentIdHint;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter student ID'**
  String get studentIdRequired;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Invalid student ID'**
  String get invalidStudentId;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Add Student'**
  String get addStudentSubmit;

  /// Dialog title
  ///
  /// In en, this message translates to:
  /// **'Remove Student'**
  String get confirmRemoveMemberTitle;

  /// Dialog content
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove student \"{name}\" from this course?'**
  String confirmRemoveMemberBody(String name);

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Remove Student'**
  String get removeStudentConfirmAction;

  /// Loading message
  ///
  /// In en, this message translates to:
  /// **'Loading group details and members...'**
  String get loadingGroupDetail;

  /// App bar title
  ///
  /// In en, this message translates to:
  /// **'Course Details'**
  String get groupDetailTitle;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Course not found'**
  String get groupNotFound;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Back to Courses'**
  String get backToGroups;

  /// Label
  ///
  /// In en, this message translates to:
  /// **'Previous Content Policy:'**
  String get previousContentPolicy;

  /// Badge label
  ///
  /// In en, this message translates to:
  /// **'Allowed for new students (Allow)'**
  String get previousContentAllowedLabel;

  /// Badge label
  ///
  /// In en, this message translates to:
  /// **'Denied for new students (Deny)'**
  String get previousContentDeniedLabel;

  /// Card header
  ///
  /// In en, this message translates to:
  /// **'Course Tools'**
  String get groupServicesAndTools;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Content & Notes'**
  String get contentAndMaterials;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Exams Bank'**
  String get examsBank;

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Send Announcement to Group'**
  String get sendGroupAnnouncement;

  /// Header title with count
  ///
  /// In en, this message translates to:
  /// **'Enrolled Students ({count})'**
  String groupMembersCountHeader(int count);

  /// Button label
  ///
  /// In en, this message translates to:
  /// **'Record Attendance'**
  String get recordAttendanceAction;

  /// Search hint
  ///
  /// In en, this message translates to:
  /// **'Search enrolled students...'**
  String get searchEnrolledStudentsHint;

  /// Empty message
  ///
  /// In en, this message translates to:
  /// **'No students enrolled in this group yet'**
  String get noStudentsInGroupYet;

  /// Empty action
  ///
  /// In en, this message translates to:
  /// **'Add First Student'**
  String get addFirstStudent;

  /// Empty message
  ///
  /// In en, this message translates to:
  /// **'No students match your search'**
  String get noStudentsMatchSearch;

  /// Tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removeFromGroupTooltip;

  /// Engagement quality active
  ///
  /// In en, this message translates to:
  /// **'Active & Engaged'**
  String get qualityActive;

  /// Engagement quality moderate
  ///
  /// In en, this message translates to:
  /// **'Moderate Engagement'**
  String get qualityModerate;

  /// Engagement quality ghost presence
  ///
  /// In en, this message translates to:
  /// **'Ghost Presence / Idle'**
  String get qualityGhostPresence;

  /// Engagement quality no data
  ///
  /// In en, this message translates to:
  /// **'No Login Today'**
  String get qualityNoData;

  /// Telemetry card title
  ///
  /// In en, this message translates to:
  /// **'Smart Engagement Telemetry'**
  String get smartTelemetryTitle;

  /// Telemetry card description
  ///
  /// In en, this message translates to:
  /// **'Distinguish between active study time and idle background sessions'**
  String get smartTelemetryDesc;

  /// Active minutes and percentage
  ///
  /// In en, this message translates to:
  /// **'Active: {mins} min ({ratio}%)'**
  String activeMinutesWithRatio(int mins, int ratio);

  /// Idle minutes count
  ///
  /// In en, this message translates to:
  /// **'Idle: {mins} min'**
  String idleMinutesWithCount(int mins);

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Active Today'**
  String get activeTodayLabel;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'Idle Today'**
  String get idleTodayLabel;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'First Login'**
  String get firstLoginLabel;

  /// Metric label
  ///
  /// In en, this message translates to:
  /// **'7-Day Active'**
  String get active7DaysLabel;

  /// Short minutes format
  ///
  /// In en, this message translates to:
  /// **'{mins}m'**
  String minutesShort(int mins);

  /// Morning time period
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get amPeriod;

  /// Evening time period
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pmPeriod;

  /// Video integrity section title
  ///
  /// In en, this message translates to:
  /// **'Video Watch Integrity'**
  String get videoIntegrityTitle;

  /// Fast-forward warning badge
  ///
  /// In en, this message translates to:
  /// **'Fast-forwarded ⚠️'**
  String get videoFastForwardWarning;

  /// Completed verified badge
  ///
  /// In en, this message translates to:
  /// **'Completed & Verified ✅'**
  String get videoCompletedHonest;

  /// Percentage completed badge
  ///
  /// In en, this message translates to:
  /// **'{percent}% completed'**
  String videoPercentageCompleted(String percent);

  /// Actual watch time vs duration
  ///
  /// In en, this message translates to:
  /// **'Actual watch: {actual} of {total} min'**
  String actualWatchMinutesRatio(int actual, int total);

  /// Last watched date label
  ///
  /// In en, this message translates to:
  /// **'Last watched: {date}'**
  String lastWatchedLabel(String date);

  /// Timeline section title
  ///
  /// In en, this message translates to:
  /// **'Activity Timeline'**
  String get activityTimelineTitle;

  /// Activity event type
  ///
  /// In en, this message translates to:
  /// **'Platform login'**
  String get eventLogin;

  /// Activity event type
  ///
  /// In en, this message translates to:
  /// **'Opened material or lesson'**
  String get eventContentOpened;

  /// Activity event type
  ///
  /// In en, this message translates to:
  /// **'Started lecture video'**
  String get eventVideoStarted;

  /// Activity event type
  ///
  /// In en, this message translates to:
  /// **'Finished lecture video'**
  String get eventVideoCompleted;

  /// Activity event type
  ///
  /// In en, this message translates to:
  /// **'Submitted assignment'**
  String get eventAssignmentSubmitted;

  /// Activity event type
  ///
  /// In en, this message translates to:
  /// **'Started exam session'**
  String get eventExamStarted;

  /// Activity event type
  ///
  /// In en, this message translates to:
  /// **'Submitted exam'**
  String get eventExamSubmitted;

  /// Relative time in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String minutesAgo(int minutes);

  /// Relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String hoursAgo(int hours);

  /// Relative time in days
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String daysAgo(int days);

  /// Just now fallback
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'New Content'**
  String get notificationTypeNewContent;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'New Assignment'**
  String get notificationTypeAssignmentCreated;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'Assignment Due Reminder'**
  String get notificationTypeAssignmentDue;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'Assignment Graded'**
  String get notificationTypeAssignmentReviewed;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'New Exam'**
  String get notificationTypeExamPublished;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'Exam Result'**
  String get notificationTypeExamResult;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'Attendance Marked'**
  String get notificationTypeAttendanceMarked;

  /// Notification type label
  ///
  /// In en, this message translates to:
  /// **'Important Announcement'**
  String get notificationTypeImportantAnnouncement;

  /// Button to mark all as read
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get markAllAsRead;

  /// Search field hint
  ///
  /// In en, this message translates to:
  /// **'Search notifications and alerts...'**
  String get searchNotificationsHint;

  /// Filter chip all
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String allNotificationsFilter(int count);

  /// Filter chip unread
  ///
  /// In en, this message translates to:
  /// **'Unread ({count})'**
  String unreadNotificationsFilter(int count);

  /// Empty state search
  ///
  /// In en, this message translates to:
  /// **'No notifications match your search'**
  String get noNotificationsMatchingSearch;

  /// Empty state unread
  ///
  /// In en, this message translates to:
  /// **'No unread notifications at this time.'**
  String get noUnreadNotifications;

  /// Empty state notifications
  ///
  /// In en, this message translates to:
  /// **'No incoming notifications yet.'**
  String get noNotificationsYet;

  /// Tooltip for notification icon
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTooltip;

  /// Card title
  ///
  /// In en, this message translates to:
  /// **'Instant Academic Alert'**
  String get instantAcademicAlertTitle;

  /// Card description
  ///
  /// In en, this message translates to:
  /// **'This announcement will be delivered directly to targeted students\' notification centers to encourage study and task completion.'**
  String get instantAcademicAlertDesc;

  /// Dropdown item
  ///
  /// In en, this message translates to:
  /// **'All Enrolled Students'**
  String get allPlatformStudents;

  /// Pill text
  ///
  /// In en, this message translates to:
  /// **'Notification scope: All enrolled students'**
  String get audienceScopeGeneral;

  /// Pill text with group name and count
  ///
  /// In en, this message translates to:
  /// **'Notification scope: {groupName} ({count} students)'**
  String audienceScopeGroup(String groupName, int count);

  /// Section title
  ///
  /// In en, this message translates to:
  /// **'Suggested Quick Templates:'**
  String get quickTemplatesTitle;

  /// Template chip label
  ///
  /// In en, this message translates to:
  /// **'📌 Session Reminder'**
  String get templateSessionReminderLabel;

  /// Template title
  ///
  /// In en, this message translates to:
  /// **'Upcoming Session Reminder'**
  String get templateSessionReminderTitle;

  /// Template body
  ///
  /// In en, this message translates to:
  /// **'Looking forward to seeing you at our next scheduled class. Please prepare your notebooks and review assigned problems.'**
  String get templateSessionReminderBody;

  /// Template chip label
  ///
  /// In en, this message translates to:
  /// **'📝 Assignment Due'**
  String get templateAssignmentReminderLabel;

  /// Template title
  ///
  /// In en, this message translates to:
  /// **'Assignment Submission Reminder'**
  String get templateAssignmentReminderTitle;

  /// Template body
  ///
  /// In en, this message translates to:
  /// **'A friendly reminder to all students to submit assignment solutions before the deadline on the platform.'**
  String get templateAssignmentReminderBody;

  /// Template chip label
  ///
  /// In en, this message translates to:
  /// **'⚠️ Exam Alert'**
  String get templateExamAlertLabel;

  /// Template title
  ///
  /// In en, this message translates to:
  /// **'Important Notice: Upcoming Exam'**
  String get templateExamAlertTitle;

  /// Template body
  ///
  /// In en, this message translates to:
  /// **'Please review all lessons and practice exercises in preparation for the upcoming exam. Best of luck!'**
  String get templateExamAlertBody;

  /// Template chip label
  ///
  /// In en, this message translates to:
  /// **'🎉 Praise & Honor'**
  String get templateExcellencePraiseLabel;

  /// Template title
  ///
  /// In en, this message translates to:
  /// **'Congratulations on Outstanding Performance'**
  String get templateExcellencePraiseTitle;

  /// Template body
  ///
  /// In en, this message translates to:
  /// **'Congratulations to all high-achieving students on the latest assessment. Keep up the phenomenal work!'**
  String get templateExcellencePraiseBody;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'e.g., Next session schedule, Important review...'**
  String get announcementTitleHint;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter announcement title'**
  String get announcementTitleRequired;

  /// Field hint
  ///
  /// In en, this message translates to:
  /// **'Write alert details or instructions for students...'**
  String get announcementBodyHint;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter announcement content'**
  String get announcementBodyRequired;

  /// Preview header
  ///
  /// In en, this message translates to:
  /// **'Live student notification preview:'**
  String get liveNotificationPreview;

  /// Preview title placeholder
  ///
  /// In en, this message translates to:
  /// **'Announcement title will appear here...'**
  String get previewTitlePlaceholder;

  /// Preview body placeholder
  ///
  /// In en, this message translates to:
  /// **'Announcement text and instructions will appear here clearly...'**
  String get previewBodyPlaceholder;

  /// Submit button
  ///
  /// In en, this message translates to:
  /// **'Send Announcement Now'**
  String get sendAnnouncementNow;

  /// Relationship label
  ///
  /// In en, this message translates to:
  /// **'Relationship: {relation}'**
  String relationshipLabel(String relation);

  /// Badge for current selected student
  ///
  /// In en, this message translates to:
  /// **'Current Student'**
  String get currentStudentBadge;

  /// Header title for child selector
  ///
  /// In en, this message translates to:
  /// **'Select Student to Monitor'**
  String get selectChildToMonitor;

  /// Enrolled children count badge
  ///
  /// In en, this message translates to:
  /// **'{count} Enrolled Children'**
  String enrolledChildrenCount(int count);

  /// Attended classes ratio description
  ///
  /// In en, this message translates to:
  /// **'Attended {present} of {total} classes'**
  String attendedClassesRatio(int present, int total);

  /// Label for exams average score
  ///
  /// In en, this message translates to:
  /// **'Exams Average'**
  String get examsAverageLabel;

  /// Count of graded exams
  ///
  /// In en, this message translates to:
  /// **'{count} Graded Exams'**
  String verifiedExamsCount(int count);

  /// Empty state for graded exams
  ///
  /// In en, this message translates to:
  /// **'No graded exams yet'**
  String get noVerifiedExamsYet;

  /// Header for attendance breakdown card
  ///
  /// In en, this message translates to:
  /// **'Attendance Breakdown'**
  String get attendanceBreakdownTitle;

  /// Error title when device is offline
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get errorNoInternetTitle;

  /// Error message when device is offline
  ///
  /// In en, this message translates to:
  /// **'Please check your Wi-Fi or mobile data connection and try again.'**
  String get errorNoInternetMessage;

  /// Hint for offline error
  ///
  /// In en, this message translates to:
  /// **'Ensure your internet connection is active, then tap Retry.'**
  String get errorNoInternetHint;

  /// Error title for request timeout
  ///
  /// In en, this message translates to:
  /// **'Request Timed Out'**
  String get errorTimeoutTitle;

  /// Error message for request timeout
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond due to poor connection.'**
  String get errorTimeoutMessage;

  /// Hint for request timeout
  ///
  /// In en, this message translates to:
  /// **'Please tap Retry or verify your network stability.'**
  String get errorTimeoutHint;

  /// Error title for invalid login credentials
  ///
  /// In en, this message translates to:
  /// **'Invalid Credentials'**
  String get errorInvalidCredentialsTitle;

  /// Error message for invalid login credentials
  ///
  /// In en, this message translates to:
  /// **'The email or password you entered does not match our records.'**
  String get errorInvalidCredentialsMessage;

  /// Hint for invalid credentials
  ///
  /// In en, this message translates to:
  /// **'Please double-check your email and password, then try again.'**
  String get errorInvalidCredentialsHint;

  /// Error title when email address is invalid or not accepted
  ///
  /// In en, this message translates to:
  /// **'Invalid Email Address'**
  String get errorEmailInvalidTitle;

  /// Error message when email address is invalid or rejected
  ///
  /// In en, this message translates to:
  /// **'The email address entered is invalid or not accepted by the system.'**
  String get errorEmailInvalidMessage;

  /// Hint when email address is invalid
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid, active email address (avoid placeholder or dummy addresses like test@...).'**
  String get errorEmailInvalidHint;

  /// Error title when email is already registered
  ///
  /// In en, this message translates to:
  /// **'Email Already Registered'**
  String get errorEmailAlreadyExistsTitle;

  /// Error message when email is already registered
  ///
  /// In en, this message translates to:
  /// **'An account with this email address already exists.'**
  String get errorEmailAlreadyExistsMessage;

  /// Hint when email is already registered
  ///
  /// In en, this message translates to:
  /// **'Try signing in with this email, or recover your password if you forgot it.'**
  String get errorEmailAlreadyExistsHint;

  /// Error title when password does not meet security requirements
  ///
  /// In en, this message translates to:
  /// **'Weak Password'**
  String get errorWeakPasswordTitle;

  /// Error message when password is too weak
  ///
  /// In en, this message translates to:
  /// **'The password must be at least 6 characters long and meet complexity requirements.'**
  String get errorWeakPasswordMessage;

  /// Hint when password is weak
  ///
  /// In en, this message translates to:
  /// **'Use a mix of letters, numbers, and symbols for a stronger password.'**
  String get errorWeakPasswordHint;

  /// Error title when rate limit is exceeded
  ///
  /// In en, this message translates to:
  /// **'Too Many Attempts'**
  String get errorRateLimitTitle;

  /// Error message when rate limit is exceeded
  ///
  /// In en, this message translates to:
  /// **'Too many requests have been made in a short time. Please wait a moment.'**
  String get errorRateLimitMessage;

  /// Hint when rate limit is exceeded
  ///
  /// In en, this message translates to:
  /// **'Please wait 5 minutes before trying again.'**
  String get errorRateLimitHint;

  /// Error title for general auth failures
  ///
  /// In en, this message translates to:
  /// **'Authentication Error'**
  String get errorAuthFailedTitle;

  /// Error message for general auth failures
  ///
  /// In en, this message translates to:
  /// **'Could not complete the authentication request. Please try again.'**
  String get errorAuthFailedMessage;

  /// Hint for general auth failures
  ///
  /// In en, this message translates to:
  /// **'Check your details and try again shortly.'**
  String get errorAuthFailedHint;

  /// Error title when auth session expired
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get errorSessionExpiredTitle;

  /// Error message when auth session expired
  ///
  /// In en, this message translates to:
  /// **'Your login session has expired for security reasons.'**
  String get errorSessionExpiredMessage;

  /// Hint for expired session
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue where you left off.'**
  String get errorSessionExpiredHint;

  /// Error title for unauthorized or forbidden access
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get errorAccessDeniedTitle;

  /// Error message for access denied
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view this content or perform this action.'**
  String get errorAccessDeniedMessage;

  /// Hint for access denied
  ///
  /// In en, this message translates to:
  /// **'If you believe this is a mistake, please contact your teacher or administrator.'**
  String get errorAccessDeniedHint;

  /// Error title when account or tenant is suspended
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get errorAccountSuspendedTitle;

  /// Hint for suspended account
  ///
  /// In en, this message translates to:
  /// **'Please contact the platform administrator or teacher for reactivation.'**
  String get errorAccountSuspendedHint;

  /// Error message when student account is suspended
  ///
  /// In en, this message translates to:
  /// **'Your account has been suspended by your instructor.'**
  String get errorUserSuspendedMessage;

  /// Title when student registration was rejected
  ///
  /// In en, this message translates to:
  /// **'Registration Rejected'**
  String get errorRegistrationRejectedTitle;

  /// Message when student registration was rejected
  ///
  /// In en, this message translates to:
  /// **'Your registration request was rejected by the instructor.'**
  String get errorRegistrationRejectedMessage;

  /// Hint when student registration was rejected
  ///
  /// In en, this message translates to:
  /// **'Please contact your instructor if you believe this was done in error.'**
  String get errorRegistrationRejectedHint;

  /// Error title when video is still being transcoded
  ///
  /// In en, this message translates to:
  /// **'Video is Processing'**
  String get errorVideoProcessingTitle;

  /// Error message when video is transcoding
  ///
  /// In en, this message translates to:
  /// **'The video is currently being processed and prepared for smooth streaming.'**
  String get errorVideoProcessingMessage;

  /// Hint for video processing
  ///
  /// In en, this message translates to:
  /// **'This might take a few minutes. Please check back shortly.'**
  String get errorVideoProcessingHint;

  /// Error title when exam time has elapsed
  ///
  /// In en, this message translates to:
  /// **'Exam Time Expired'**
  String get errorExamExpiredTitle;

  /// Error message when exam time has elapsed
  ///
  /// In en, this message translates to:
  /// **'The allowed time window for this exam has ended.'**
  String get errorExamExpiredMessage;

  /// Hint for expired exam
  ///
  /// In en, this message translates to:
  /// **'Your submitted answers were saved automatically. You can review your score or contact your teacher.'**
  String get errorExamExpiredHint;

  /// Error title when student already submitted exam
  ///
  /// In en, this message translates to:
  /// **'Exam Already Submitted'**
  String get errorExamAlreadySubmittedTitle;

  /// Error message when student already submitted exam
  ///
  /// In en, this message translates to:
  /// **'You have already submitted your answers for this exam.'**
  String get errorExamAlreadySubmittedMessage;

  /// Hint for already submitted exam
  ///
  /// In en, this message translates to:
  /// **'You cannot submit this exam again unless permitted by your teacher.'**
  String get errorExamAlreadySubmittedHint;

  /// Error title when max exam attempts reached
  ///
  /// In en, this message translates to:
  /// **'Attempt Limit Reached'**
  String get errorAttemptsLimitReachedTitle;

  /// Error message when max exam attempts reached
  ///
  /// In en, this message translates to:
  /// **'You have reached the maximum allowed attempts for this exam.'**
  String get errorAttemptsLimitReachedMessage;

  /// Hint for max attempts reached
  ///
  /// In en, this message translates to:
  /// **'Please contact your teacher if you require an additional attempt.'**
  String get errorAttemptsLimitReachedHint;

  /// Error title when content is draft
  ///
  /// In en, this message translates to:
  /// **'Content Not Published'**
  String get errorContentNotPublishedTitle;

  /// Error message when content is draft
  ///
  /// In en, this message translates to:
  /// **'This content is still a draft and has not been published to students yet.'**
  String get errorContentNotPublishedMessage;

  /// Hint when content is unpublished
  ///
  /// In en, this message translates to:
  /// **'Please return to the main feed and wait for publication.'**
  String get errorContentNotPublishedHint;

  /// Error title for 500 or backend failure
  ///
  /// In en, this message translates to:
  /// **'Server Connection Error'**
  String get errorServerTitle;

  /// Error message for server error
  ///
  /// In en, this message translates to:
  /// **'We are experiencing temporary difficulties communicating with the server.'**
  String get errorServerMessage;

  /// Hint for server error
  ///
  /// In en, this message translates to:
  /// **'Please try again shortly; our systems are working to restore service.'**
  String get errorServerHint;

  /// Error title when resource not found
  ///
  /// In en, this message translates to:
  /// **'Item Not Found'**
  String get errorNotFoundTitle;

  /// Error message when resource not found
  ///
  /// In en, this message translates to:
  /// **'The requested item could not be found. It may have been moved or removed.'**
  String get errorNotFoundMessage;

  /// Hint when item is not found
  ///
  /// In en, this message translates to:
  /// **'Please verify the link or return to the previous page.'**
  String get errorNotFoundHint;

  /// Error title for form validation errors
  ///
  /// In en, this message translates to:
  /// **'Incomplete Data'**
  String get errorValidationTitle;

  /// Error message for form validation errors
  ///
  /// In en, this message translates to:
  /// **'Please check the required fields and ensure all inputs are valid.'**
  String get errorValidationMessage;

  /// Hint for form validation errors
  ///
  /// In en, this message translates to:
  /// **'Correct any fields highlighted in red to proceed.'**
  String get errorValidationHint;

  /// Label displaying error code
  ///
  /// In en, this message translates to:
  /// **'Error Code: {code}'**
  String errorCodeLabel(String code);

  /// Button label to copy error details for support
  ///
  /// In en, this message translates to:
  /// **'Copy Error Details'**
  String get copyErrorDetails;

  /// Snackbar confirming error details copied
  ///
  /// In en, this message translates to:
  /// **'Error details copied to clipboard successfully'**
  String get errorDetailsCopied;

  /// Button to go back
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// Button to sign in again after session expiry
  ///
  /// In en, this message translates to:
  /// **'Sign In Again'**
  String get signInAgain;

  /// Section header for actionable error tips
  ///
  /// In en, this message translates to:
  /// **'What you can do:'**
  String get actionTip;

  /// Title in app bar for video lesson
  ///
  /// In en, this message translates to:
  /// **'Watch Educational Lesson'**
  String get watchLessonTitle;

  /// Badge showing secure CDN provider
  ///
  /// In en, this message translates to:
  /// **'Secure Bunny CDN'**
  String get secureCdnBadge;

  /// Loading video text
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get loadingVideo;

  /// Keyboard spacebar key label
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get keySpace;

  /// Play pause shortcut label
  ///
  /// In en, this message translates to:
  /// **'Play / Pause'**
  String get playPauseAction;

  /// Forward/backward 10s shortcut
  ///
  /// In en, this message translates to:
  /// **'Seek 10 seconds'**
  String get seek10Seconds;

  /// Toggle fullscreen action
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreenAction;

  /// Title for lesson academic stats
  ///
  /// In en, this message translates to:
  /// **'Lesson Academic Progress'**
  String get lessonAcademicProgress;

  /// Completed status
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// In progress status badge
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// Not started status badge
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get statusNotStarted;

  /// Completion rate with percentage
  ///
  /// In en, this message translates to:
  /// **'Completion: {percent}%'**
  String completionPercentage(int percent);

  /// Progress in minutes ratio
  ///
  /// In en, this message translates to:
  /// **'{current} / {total} min'**
  String minutesRatio(int current, int total);

  /// Academic milestones title
  ///
  /// In en, this message translates to:
  /// **'Academic Milestones:'**
  String get academicMilestonesTitle;

  /// 25% milestone
  ///
  /// In en, this message translates to:
  /// **'Foundational Concepts'**
  String get milestoneConcepts;

  /// 50% milestone
  ///
  /// In en, this message translates to:
  /// **'Solved Examples & Application'**
  String get milestoneExamples;

  /// 75% milestone
  ///
  /// In en, this message translates to:
  /// **'Advanced Problems'**
  String get milestoneAdvanced;

  /// 100% milestone
  ///
  /// In en, this message translates to:
  /// **'Full Lesson Completion'**
  String get milestoneCompletion;

  /// Default title when video title is null
  ///
  /// In en, this message translates to:
  /// **'Educational Lesson'**
  String get defaultLessonTitle;

  /// CDN streaming notice
  ///
  /// In en, this message translates to:
  /// **'Protected stream via Bunny Stream CDN'**
  String get protectedStreamCdnNotice;

  /// Header for lesson notes
  ///
  /// In en, this message translates to:
  /// **'Lesson Notes & Topics:'**
  String get lessonNotesAndTopics;

  /// Message while video is processing
  ///
  /// In en, this message translates to:
  /// **'Processing video...'**
  String get videoProcessingMessage;

  /// Message when video processing fails
  ///
  /// In en, this message translates to:
  /// **'Video processing failed'**
  String get videoProcessingFailed;

  /// Placeholder for untitled video
  ///
  /// In en, this message translates to:
  /// **'Untitled Video Lesson'**
  String get videoLessonUntitled;

  /// Percentage watched text
  ///
  /// In en, this message translates to:
  /// **'Watched {percent}%'**
  String watchedPercentage(int percent);

  /// Placeholder badge on thumbnail
  ///
  /// In en, this message translates to:
  /// **'Video Lesson'**
  String get videoLessonPlaceholder;

  /// Error picking video
  ///
  /// In en, this message translates to:
  /// **'Failed to select video file: {error}'**
  String videoPickFailed(String error);

  /// Validation error when no file picked
  ///
  /// In en, this message translates to:
  /// **'Please select a video file first'**
  String get videoPleaseSelectFile;

  /// Toast on video upload success
  ///
  /// In en, this message translates to:
  /// **'Video uploaded to Bunny Stream successfully and is processing!'**
  String get videoUploadSuccessToast;

  /// Title when video is pending upload
  ///
  /// In en, this message translates to:
  /// **'Lesson Under Preparation'**
  String get videoPendingUploadTitle;

  /// Description for students when video is pending upload
  ///
  /// In en, this message translates to:
  /// **'The teacher is currently preparing and uploading the video for this lesson. Please check back later.'**
  String get studentVideoPendingUploadDesc;

  /// Title for teacher when video is not uploaded
  ///
  /// In en, this message translates to:
  /// **'No Video Uploaded Yet'**
  String get teacherVideoNotUploadedTitle;

  /// Description for teacher when video is not uploaded
  ///
  /// In en, this message translates to:
  /// **'Lesson created, but the video file has not been uploaded to Bunny Stream yet. You can upload it now so students can watch.'**
  String get teacherVideoNotUploadedDesc;

  /// Badge for pending video upload
  ///
  /// In en, this message translates to:
  /// **'Pending Video Upload'**
  String get teacherVideoNotUploadedBadge;

  /// Button to go back to content library/feed
  ///
  /// In en, this message translates to:
  /// **'Back to Content'**
  String get backToContentAction;

  /// Error message when lesson video is not found
  ///
  /// In en, this message translates to:
  /// **'The requested educational lesson could not be found.'**
  String get videoNotFoundMessage;

  /// Title of video upload dialog
  ///
  /// In en, this message translates to:
  /// **'Upload New Lesson Video'**
  String get uploadNewLessonVideo;

  /// Subtitle in video upload dialog
  ///
  /// In en, this message translates to:
  /// **'Fast and encrypted hosting via Bunny CDN'**
  String get fastEncryptedCdnHosting;

  /// Picker loading state
  ///
  /// In en, this message translates to:
  /// **'Opening file picker...'**
  String get openingDocuments;

  /// Picker placeholder
  ///
  /// In en, this message translates to:
  /// **'Click to select video file (MP4, MOV)'**
  String get clickToPickVideo;

  /// Transcoding hint
  ///
  /// In en, this message translates to:
  /// **'Automatic encryption & transcoding to 1080p, 720p, 480p'**
  String get autoTranscodeHint;

  /// Tooltip to change selected file
  ///
  /// In en, this message translates to:
  /// **'Change file'**
  String get changeFile;

  /// Form label for video title
  ///
  /// In en, this message translates to:
  /// **'Lesson Title'**
  String get lessonTitleLabel;

  /// Form hint for video title
  ///
  /// In en, this message translates to:
  /// **'e.g. Trigonometric Functions - Part 1'**
  String get lessonTitleHint;

  /// Validation error for video title
  ///
  /// In en, this message translates to:
  /// **'Please enter lesson title'**
  String get lessonTitleRequired;

  /// Form label for video description
  ///
  /// In en, this message translates to:
  /// **'Lesson Topics & Notes (Optional)'**
  String get lessonNotesLabel;

  /// Form hint for video description
  ///
  /// In en, this message translates to:
  /// **'Important takeaways, formulas, homework...'**
  String get lessonNotesHint;

  /// Status text while uploading
  ///
  /// In en, this message translates to:
  /// **'Uploading video to Bunny Stream...'**
  String get uploadingVideoToCdn;

  /// Button label while uploading
  ///
  /// In en, this message translates to:
  /// **'Uploading ({percent}%)...'**
  String uploadingWithPercentage(int percent);

  /// Button label to start upload
  ///
  /// In en, this message translates to:
  /// **'Start Upload'**
  String get startUpload;

  /// Player error message
  ///
  /// In en, this message translates to:
  /// **'Unable to play video, please check your internet connection.'**
  String get videoPlaybackError;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// Loading adaptive player text
  ///
  /// In en, this message translates to:
  /// **'Loading adaptive stream...'**
  String get loadingAdaptiveStream;

  /// Resume banner text
  ///
  /// In en, this message translates to:
  /// **'Resume from minute {time}?'**
  String resumeFromMinute(String time);

  /// Resume button label
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeAction;

  /// Prefix for group content title
  ///
  /// In en, this message translates to:
  /// **'Content: {groupName}'**
  String groupContentPrefix(String groupName);

  /// Default group content title
  ///
  /// In en, this message translates to:
  /// **'Group Study Materials'**
  String get groupContentDefault;

  /// Tooltip back to student dashboard
  ///
  /// In en, this message translates to:
  /// **'Back to student dashboard'**
  String get backToStudentDashboard;

  /// Refresh content tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh content'**
  String get refreshContent;

  /// Search field placeholder in student feed
  ///
  /// In en, this message translates to:
  /// **'Search notes, summaries, or videos...'**
  String get searchContentPlaceholder;

  /// All filter chip with count
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String filterAllWithCount(int count);

  /// PDF notes filter chip with count
  ///
  /// In en, this message translates to:
  /// **'Notes ({count})'**
  String filterPdfsWithCount(int count);

  /// Images filter chip with count
  ///
  /// In en, this message translates to:
  /// **'Images ({count})'**
  String filterImagesWithCount(int count);

  /// Videos filter chip with count
  ///
  /// In en, this message translates to:
  /// **'Videos ({count})'**
  String filterVideosWithCount(int count);

  /// Empty state when no materials published
  ///
  /// In en, this message translates to:
  /// **'No educational materials published in this group yet.\nNotes and lessons will appear here once published by the teacher.'**
  String get noContentPublishedYet;

  /// Search empty state
  ///
  /// In en, this message translates to:
  /// **'No study materials match your search \"{query}\"'**
  String noMatchingContentFound(String query);

  /// Toast when content created
  ///
  /// In en, this message translates to:
  /// **'Educational material created and published successfully'**
  String get contentCreatedToast;

  /// Toast when content updated
  ///
  /// In en, this message translates to:
  /// **'Educational material updated successfully'**
  String get contentUpdatedToast;

  /// Toast when lecture video upload begins
  ///
  /// In en, this message translates to:
  /// **'Lecture video processing and upload started successfully'**
  String get videoProcessingStartedToast;

  /// Generic back tooltip
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backTooltip;

  /// Teacher content library title
  ///
  /// In en, this message translates to:
  /// **'Educational Content Library'**
  String get teacherContentLibraryTitle;

  /// Refresh button tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// Stat card label
  ///
  /// In en, this message translates to:
  /// **'Total Materials'**
  String get totalMaterials;

  /// Stat card label
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get publishedToStudents;

  /// Stat card label
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get draftsInProgress;

  /// Search field hint for teacher
  ///
  /// In en, this message translates to:
  /// **'Search group materials and notes...'**
  String get searchContentTeacherHint;

  /// Published filter chip with count
  ///
  /// In en, this message translates to:
  /// **'Published ({count})'**
  String filterPublishedWithCount(int count);

  /// Drafts filter chip with count
  ///
  /// In en, this message translates to:
  /// **'Drafts ({count})'**
  String filterDraftsWithCount(int count);

  /// Archived filter chip with count
  ///
  /// In en, this message translates to:
  /// **'Archived ({count})'**
  String filterArchivedWithCount(int count);

  /// Empty state in teacher content library
  ///
  /// In en, this message translates to:
  /// **'No educational content in this category yet'**
  String get emptyContentCategory;

  /// Empty state CTA button
  ///
  /// In en, this message translates to:
  /// **'Add First Material'**
  String get addFirstContent;

  /// Empty search/filter results
  ///
  /// In en, this message translates to:
  /// **'No study materials match the selected criteria'**
  String get noMaterialsMatchFilter;

  /// Delete dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get deleteConfirmTitle;

  /// Delete confirmation text
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete \"{title}\"?'**
  String deleteItemConfirmMessage(String title);

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// Dialog title for edit content
  ///
  /// In en, this message translates to:
  /// **'Edit Educational Material'**
  String get editContentDialogTitle;

  /// Dialog title for new content
  ///
  /// In en, this message translates to:
  /// **'Add New Educational Material'**
  String get newContentDialogTitle;

  /// Form label
  ///
  /// In en, this message translates to:
  /// **'Content Title *'**
  String get contentTitleInputLabel;

  /// Form hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Geometry & Trigonometry Formulas Sheet'**
  String get contentTitleInputHint;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter content title'**
  String get contentTitleRequired;

  /// Form label
  ///
  /// In en, this message translates to:
  /// **'Description or Instructions for Students (Optional)'**
  String get contentDescInputLabel;

  /// Form hint
  ///
  /// In en, this message translates to:
  /// **'Important takeaways or attached notes…'**
  String get contentDescInputHint;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Material Type:'**
  String get materialTypeLabel;

  /// Section header
  ///
  /// In en, this message translates to:
  /// **'Publication Status:'**
  String get publicationStatusLabel;

  /// Choice chip label
  ///
  /// In en, this message translates to:
  /// **'Private draft (hidden from students)'**
  String get draftPrivateNotice;

  /// Choice chip label
  ///
  /// In en, this message translates to:
  /// **'Immediate publication for students'**
  String get publishImmediateNotice;

  /// Checkbox label
  ///
  /// In en, this message translates to:
  /// **'Attach educational file (PDF / Image / Document)'**
  String get attachMaterialFile;

  /// Form label
  ///
  /// In en, this message translates to:
  /// **'Attached File Name *'**
  String get attachedFileNameLabel;

  /// Form hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Calculus_Formulas_Sheet.pdf'**
  String get attachedFileNameHint;

  /// Validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter or select a file name'**
  String get fileNameRequired;

  /// Browse button label
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browseFileAction;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create & Save'**
  String get createAndSave;

  /// File size label
  ///
  /// In en, this message translates to:
  /// **'File Size: {size}'**
  String fileSizeLabel(String size);

  /// File type label
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String fileTypeLabel(String type);

  /// Loading state in viewer sheet
  ///
  /// In en, this message translates to:
  /// **'Preparing secure file link...'**
  String get preparingSecureUrl;

  /// Error in viewer sheet
  ///
  /// In en, this message translates to:
  /// **'Unable to generate secure file link at this time'**
  String get secureUrlErrorFallback;

  /// Catch block error in viewer sheet
  ///
  /// In en, this message translates to:
  /// **'An error occurred while preparing the secure link'**
  String get secureUrlGenericError;

  /// Toast when URL copied
  ///
  /// In en, this message translates to:
  /// **'Secure link copied to clipboard successfully'**
  String get secureUrlCopied;

  /// Button label to copy signed URL
  ///
  /// In en, this message translates to:
  /// **'Copy Secure Link'**
  String get copySecureUrlAction;

  /// Button label to open or download
  ///
  /// In en, this message translates to:
  /// **'Download / Open File'**
  String get downloadOrOpenFile;

  /// Security disclaimer in viewer sheet
  ///
  /// In en, this message translates to:
  /// **'Content is encrypted and designated for authorized students only. Links expire within 60 minutes for security.'**
  String get contentSecurityDisclaimer;

  /// Close tooltip
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeTooltip;

  /// Published date format
  ///
  /// In en, this message translates to:
  /// **'Published: {date}'**
  String publishedDatePrefix(String date);

  /// Created date format
  ///
  /// In en, this message translates to:
  /// **'Created: {date}'**
  String createdDatePrefix(String date);

  /// Button label in card
  ///
  /// In en, this message translates to:
  /// **'Upload Video'**
  String get uploadVideoAction;

  /// Tooltip on visibility icon
  ///
  /// In en, this message translates to:
  /// **'Published (click to make draft)'**
  String get publishedTooltip;

  /// Tooltip on visibility icon
  ///
  /// In en, this message translates to:
  /// **'Draft (click to publish)'**
  String get draftTooltip;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Upload / Update Lecture Video'**
  String get uploadUpdateLectureVideo;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Download / Open File'**
  String get downloadOrOpenAction;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Edit Details'**
  String get editMetadataAction;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Make Draft'**
  String get convertToDraft;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Publish to Students'**
  String get publishToStudents;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchiveMaterial;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Archive Material'**
  String get archiveMaterial;

  /// Popup menu item
  ///
  /// In en, this message translates to:
  /// **'Permanent Delete'**
  String get permanentDelete;

  /// Action tooltip on student card
  ///
  /// In en, this message translates to:
  /// **'Preview and download note'**
  String get previewAndDownloadNote;

  /// Content type image
  ///
  /// In en, this message translates to:
  /// **'Diagram / Image'**
  String get contentTypeImage;

  /// Content type assignment
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get contentTypeAssignment;

  /// Content type exam
  ///
  /// In en, this message translates to:
  /// **'Exam / Quiz'**
  String get contentTypeExam;

  /// Content status archived
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get statusArchived;

  /// Loading educational content indicator
  ///
  /// In en, this message translates to:
  /// **'Loading educational content...'**
  String get loadingContent;

  /// Group name with colon
  ///
  /// In en, this message translates to:
  /// **'Group: {name}'**
  String groupColon(String name);

  /// Duration in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesDuration(int minutes);

  /// Points score
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String scorePoints(int points);

  /// Version and attempts label
  ///
  /// In en, this message translates to:
  /// **'Version: v{version} | Attempts: {count}'**
  String examVersionAttempts(int version, int count);

  /// Student status available
  ///
  /// In en, this message translates to:
  /// **'Available to Start'**
  String get availableToStart;

  /// Student status in progress
  ///
  /// In en, this message translates to:
  /// **'In Progress (Resume)'**
  String get inProgressResume;

  /// Exam passed badge
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get passed;

  /// Exam failed badge
  ///
  /// In en, this message translates to:
  /// **'Did Not Pass'**
  String get notPassed;

  /// Published badge
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get publishedBadge;

  /// Draft badge
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftBadge;

  /// Reference sheet modal title
  ///
  /// In en, this message translates to:
  /// **'SAT Official Reference Sheet'**
  String get satReferenceSheetTitle;

  /// Calculator modal title
  ///
  /// In en, this message translates to:
  /// **'Digital SAT Scientific Calculator'**
  String get satCalculatorTitle;

  /// Formula section area and circumference
  ///
  /// In en, this message translates to:
  /// **'Area & Circumference of Plane Figures'**
  String get areaCircumferenceSection;

  /// Circle area label
  ///
  /// In en, this message translates to:
  /// **'Circle Area'**
  String get circleArea;

  /// Circle circumference label
  ///
  /// In en, this message translates to:
  /// **'Circle Circumference'**
  String get circleCircumference;

  /// Rectangle area label
  ///
  /// In en, this message translates to:
  /// **'Rectangle Area'**
  String get rectangleArea;

  /// Triangle area label
  ///
  /// In en, this message translates to:
  /// **'Triangle Area'**
  String get triangleArea;

  /// Volumes section title
  ///
  /// In en, this message translates to:
  /// **'3D Volumes'**
  String get volumesSection;

  /// Rectangular prism volume
  ///
  /// In en, this message translates to:
  /// **'Rectangular Prism Volume'**
  String get rectangularPrismVolume;

  /// Cylinder volume
  ///
  /// In en, this message translates to:
  /// **'Right Cylinder Volume'**
  String get cylinderVolume;

  /// Sphere volume
  ///
  /// In en, this message translates to:
  /// **'Sphere Volume'**
  String get sphereVolume;

  /// Cone volume
  ///
  /// In en, this message translates to:
  /// **'Right Cone Volume'**
  String get coneVolume;

  /// Pyramid volume
  ///
  /// In en, this message translates to:
  /// **'Right Pyramid Volume'**
  String get pyramidVolume;

  /// Right triangles section
  ///
  /// In en, this message translates to:
  /// **'Right & Special Triangles'**
  String get rightTrianglesSection;

  /// Pythagorean theorem
  ///
  /// In en, this message translates to:
  /// **'Pythagorean Theorem'**
  String get pythagoreanTheorem;

  /// 30-60-90 triangle
  ///
  /// In en, this message translates to:
  /// **'30° - 60° - 90° Triangle'**
  String get triangle306090;

  /// 30-60-90 sides
  ///
  /// In en, this message translates to:
  /// **'Sides: x, x√3, 2x'**
  String get triangle306090Sides;

  /// 45-45-90 triangle
  ///
  /// In en, this message translates to:
  /// **'45° - 45° - 90° Triangle'**
  String get triangle454590;

  /// 45-45-90 sides
  ///
  /// In en, this message translates to:
  /// **'Sides: s, s, s√2'**
  String get triangle454590Sides;

  /// Degrees & radians section
  ///
  /// In en, this message translates to:
  /// **'Degrees & Radians'**
  String get degreesRadiansSection;

  /// Sum of triangle angles
  ///
  /// In en, this message translates to:
  /// **'Sum of Triangle Angles'**
  String get triangleAnglesSum;

  /// Full rotation radians
  ///
  /// In en, this message translates to:
  /// **'Full Rotation in Radians'**
  String get fullCircleRadians;

  /// Degrees to radians conversion
  ///
  /// In en, this message translates to:
  /// **'Degrees to Radians Conversion'**
  String get degreesToRadians;

  /// Teacher exams page title
  ///
  /// In en, this message translates to:
  /// **'Exam Management'**
  String get teacherExamsTitle;

  /// Teacher group exams title
  ///
  /// In en, this message translates to:
  /// **'Exams: {groupName}'**
  String groupExamsTitle(String groupName);

  /// Exam details header subtitle
  ///
  /// In en, this message translates to:
  /// **'Version: v{version} (Frozen) • Attempts: {count}'**
  String examDetailsVersionFrozen(int version, int count);

  /// Create new version button
  ///
  /// In en, this message translates to:
  /// **'Create New Version v{version}'**
  String createNewVersionButton(int version);

  /// Toast when new version created
  ///
  /// In en, this message translates to:
  /// **'New draft version created and previous version frozen'**
  String get newVersionCreatedSuccess;

  /// Empty attempts title
  ///
  /// In en, this message translates to:
  /// **'No submissions yet'**
  String get noAttemptsYet;

  /// Empty attempts subtitle
  ///
  /// In en, this message translates to:
  /// **'Student attempts and scores will appear here once they finish their exams'**
  String get noAttemptsYetSubtitle;

  /// Fallback avatar initial
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get studentInitialFallback;

  /// Fallback student name
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get studentFallbackName;

  /// Started date prefix
  ///
  /// In en, this message translates to:
  /// **'Started: {date}'**
  String startedDatePrefix(String date);

  /// Empty exams title
  ///
  /// In en, this message translates to:
  /// **'No exams added to this group'**
  String get noExamsForGroup;

  /// Empty exams subtitle
  ///
  /// In en, this message translates to:
  /// **'Start building the first digital exam for students with frozen snapshots and automatic grading'**
  String get noExamsForGroupSubtitle;

  /// Empty exams action button
  ///
  /// In en, this message translates to:
  /// **'Build First Exam'**
  String get buildFirstExam;

  /// Floating action button label
  ///
  /// In en, this message translates to:
  /// **'Build Exam'**
  String get buildExamAction;

  /// Student exams page title
  ///
  /// In en, this message translates to:
  /// **'My Exams & Assessments'**
  String get myExamsTitle;

  /// Back to home button tooltip
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHomeTooltip;

  /// Filter available
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get filterAvailable;

  /// Filter in progress
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get filterInProgress;

  /// Filter completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// Empty filtered exams title
  ///
  /// In en, this message translates to:
  /// **'No exams in this category'**
  String get noExamsInFilter;

  /// Empty filtered exams subtitle
  ///
  /// In en, this message translates to:
  /// **'Try switching to another filter to view exams'**
  String get noExamsInFilterSubtitle;

  /// Empty published exams subtitle
  ///
  /// In en, this message translates to:
  /// **'No exams published for your study groups currently'**
  String get noPublishedExams;

  /// Exam intro appbar title
  ///
  /// In en, this message translates to:
  /// **'Exam Rules & Instructions'**
  String get examRulesAndGuidelines;

  /// Max score label
  ///
  /// In en, this message translates to:
  /// **'Max Score'**
  String get maxScoreLabel;

  /// Passing score title
  ///
  /// In en, this message translates to:
  /// **'Passing Score'**
  String get passingScoreTitle;

  /// Not specified label
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// Retake policy title
  ///
  /// In en, this message translates to:
  /// **'Retake Policy'**
  String get retakePolicy;

  /// Allowed retake label
  ///
  /// In en, this message translates to:
  /// **'Allowed (Highest Score Recorded)'**
  String get allowedHighestScore;

  /// Not allowed retake label
  ///
  /// In en, this message translates to:
  /// **'Not Allowed'**
  String get notAllowed;

  /// Instructions heading
  ///
  /// In en, this message translates to:
  /// **'Important Guidelines Before Starting:'**
  String get importantInstructionsBeforeStart;

  /// Rule timer starts
  ///
  /// In en, this message translates to:
  /// **'The timer starts immediately upon clicking \'Start Exam\' synchronized with platform servers.'**
  String get ruleTimerStartsImmediately;

  /// Rule auto save
  ///
  /// In en, this message translates to:
  /// **'Your answers are automatically saved as you navigate between questions to protect against connection loss.'**
  String get ruleAutoSaveAnswers;

  /// Rule auto submit
  ///
  /// In en, this message translates to:
  /// **'When the time expires, your exam will automatically submit and calculate your grade immediately.'**
  String get ruleAutoSubmitOnTimeout;

  /// Rule do not close
  ///
  /// In en, this message translates to:
  /// **'Please do not close or refresh the exam window until confirmation of successful submission appears.'**
  String get ruleDoNotCloseWindow;

  /// Resume exam button
  ///
  /// In en, this message translates to:
  /// **'Resume In-Progress Exam'**
  String get resumeCurrentExam;

  /// Start exam button
  ///
  /// In en, this message translates to:
  /// **'Start Exam Now'**
  String get startExamNow;

  /// Already completed notice
  ///
  /// In en, this message translates to:
  /// **'You have already completed this exam with score: {score}/{maxScore}. Retakes are not permitted.'**
  String examAlreadyCompletedNoRetake(int score, int maxScore);

  /// Cannot take exam notice
  ///
  /// In en, this message translates to:
  /// **'This exam cannot be taken at this time.'**
  String get examCannotBeTaken;

  /// Confirm submit dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Exam Submission'**
  String get confirmSubmitExamTitle;

  /// Answered questions count
  ///
  /// In en, this message translates to:
  /// **'You answered {answered} out of {total} questions.'**
  String answeredQuestionsCount(int answered, int total);

  /// Unanswered warning
  ///
  /// In en, this message translates to:
  /// **'Warning: There are {count} unanswered questions!'**
  String unansweredWarning(int count);

  /// Confirm submit body question
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to finish and submit your exam now?'**
  String get confirmSubmitQuestion;

  /// Continue solving button
  ///
  /// In en, this message translates to:
  /// **'Continue Solving'**
  String get continueSolving;

  /// Yes submit button
  ///
  /// In en, this message translates to:
  /// **'Yes, Submit Exam'**
  String get yesSubmitExam;

  /// Question progress title
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionProgress(int current, int total);

  /// Solved count subtitle
  ///
  /// In en, this message translates to:
  /// **'Solved: {answered}/{total}'**
  String solvedCount(int answered, int total);

  /// Choose correct answer heading
  ///
  /// In en, this message translates to:
  /// **'Select the correct answer:'**
  String get chooseCorrectAnswer;

  /// Previous question button
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousQuestion;

  /// Next question button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextQuestion;

  /// Submit exam button
  ///
  /// In en, this message translates to:
  /// **'Submit Exam Now'**
  String get submitExamNow;

  /// Reference sheet action tooltip
  ///
  /// In en, this message translates to:
  /// **'Reference Sheet (SAT Formulas)'**
  String get referenceSheetTooltip;

  /// Calculator action tooltip
  ///
  /// In en, this message translates to:
  /// **'Scientific Calculator'**
  String get calculatorTooltip;

  /// Exam result appbar title
  ///
  /// In en, this message translates to:
  /// **'Exam Results'**
  String get examResultTitle;

  /// Passed headline
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You passed the exam successfully'**
  String get congratulationsPassed;

  /// Failed headline
  ///
  /// In en, this message translates to:
  /// **'Unfortunately, you did not reach the passing score'**
  String get sorryNotPassed;

  /// Percentage label
  ///
  /// In en, this message translates to:
  /// **'Percentage: {percentage}%'**
  String percentageLabel(String percentage);

  /// Required passing score label
  ///
  /// In en, this message translates to:
  /// **'Required Passing Score: {passing} out of {max}'**
  String requiredPassingScore(int passing, int max);

  /// Submission date label
  ///
  /// In en, this message translates to:
  /// **'Submission Date'**
  String get examSubmissionDateTitle;

  /// Attempt status label
  ///
  /// In en, this message translates to:
  /// **'Attempt Status'**
  String get attemptStatusLabel;

  /// Retake policy label
  ///
  /// In en, this message translates to:
  /// **'Retake Policy'**
  String get retakePolicyLabel;

  /// Retake allowed policy
  ///
  /// In en, this message translates to:
  /// **'Allowed (Highest score retained)'**
  String get retakeAllowedBestScore;

  /// Back to exams button
  ///
  /// In en, this message translates to:
  /// **'Back to Exams List'**
  String get backToExamsList;

  /// Create exam appbar title
  ///
  /// In en, this message translates to:
  /// **'Build New Exam'**
  String get createExamTitle;

  /// General settings section title
  ///
  /// In en, this message translates to:
  /// **'Basic Exam Configuration'**
  String get examGeneralSettings;

  /// Exam title field
  ///
  /// In en, this message translates to:
  /// **'Exam Title *'**
  String get examTitleField;

  /// Exam title hint
  ///
  /// In en, this message translates to:
  /// **'e.g., Comprehensive Exam on Limits & Continuity'**
  String get examTitleHint;

  /// Exam title validation
  ///
  /// In en, this message translates to:
  /// **'Please enter exam title'**
  String get examTitleRequired;

  /// Duration minutes field
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get durationMinutesField;

  /// Positive number validator
  ///
  /// In en, this message translates to:
  /// **'Positive number'**
  String get positiveNumberRequired;

  /// Max score field
  ///
  /// In en, this message translates to:
  /// **'Max Score'**
  String get maxScoreField;

  /// Passing score field
  ///
  /// In en, this message translates to:
  /// **'Passing Score (Optional)'**
  String get passingScoreField;

  /// Shuffle questions switch title
  ///
  /// In en, this message translates to:
  /// **'Shuffle questions randomly for each student'**
  String get shuffleQuestionsTitle;

  /// Shuffle questions switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Locks randomized order per attempt upon starting'**
  String get shuffleQuestionsSubtitle;

  /// Show result switch title
  ///
  /// In en, this message translates to:
  /// **'Show result to student immediately upon submission'**
  String get showResultTitle;

  /// Show result switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Displays server-graded score and percentage'**
  String get showResultSubtitle;

  /// Allow retake switch title
  ///
  /// In en, this message translates to:
  /// **'Allow Exam Retakes'**
  String get allowRetakeTitle;

  /// Allow retake switch subtitle
  ///
  /// In en, this message translates to:
  /// **'The platform retains the highest score achieved in student record'**
  String get allowRetakeSubtitle;

  /// Questions section title
  ///
  /// In en, this message translates to:
  /// **'Questions ({count})'**
  String questionsSectionTitle(int count);

  /// Question number card title
  ///
  /// In en, this message translates to:
  /// **'Question #{number}'**
  String questionNumberTitle(int number);

  /// Question prompt field label
  ///
  /// In en, this message translates to:
  /// **'Question Prompt *'**
  String get questionTextField;

  /// Question prompt hint
  ///
  /// In en, this message translates to:
  /// **'Type the problem here...'**
  String get questionTextHint;

  /// Question type field label
  ///
  /// In en, this message translates to:
  /// **'Question Type'**
  String get questionTypeField;

  /// Points field label
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get pointsField;

  /// Options section prompt
  ///
  /// In en, this message translates to:
  /// **'Options (select the correct choice):'**
  String get optionsSelectCorrectPrompt;

  /// Option hint text
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String optionNumberHint(int number);

  /// Save and publish button label
  ///
  /// In en, this message translates to:
  /// **'Save & Publish Exam (Freeze v1)'**
  String get saveAndPublishExam;

  /// Exam created toast
  ///
  /// In en, this message translates to:
  /// **'Exam created and published successfully as frozen version'**
  String get examBuiltAndPublishedSuccess;

  /// Question text required validation toast
  ///
  /// In en, this message translates to:
  /// **'Please enter text for question #{number}'**
  String fillQuestionTextError(int number);

  /// Question option correct validation toast
  ///
  /// In en, this message translates to:
  /// **'Please select and fill the correct option for question #{number}'**
  String selectCorrectOptionError(int number);

  /// Option true
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get optionTrue;

  /// Option false
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get optionFalse;

  /// Multiple choice type
  ///
  /// In en, this message translates to:
  /// **'Multiple Choice'**
  String get questionTypeMultipleChoice;

  /// True or false type
  ///
  /// In en, this message translates to:
  /// **'True / False'**
  String get questionTypeTrueFalse;

  /// Attempt status in progress
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get attemptStatusInProgress;

  /// Attempt status submitted
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get attemptStatusSubmitted;

  /// Attempt status expired
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get attemptStatusExpired;

  /// Exam status draft
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get examStatusDraft;

  /// Exam status published
  ///
  /// In en, this message translates to:
  /// **'Published (Frozen)'**
  String get examStatusPublished;

  /// Submission status reviewed
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get submissionStatusReviewed;

  /// Submission status late
  ///
  /// In en, this message translates to:
  /// **'Late Submission'**
  String get submissionStatusLate;

  /// Group label prefix
  ///
  /// In en, this message translates to:
  /// **'Group: {groupName}'**
  String groupLabelPrefix(String groupName);

  /// Due at prefix
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String dueAtPrefix(String date);

  /// Deadline prefix
  ///
  /// In en, this message translates to:
  /// **'Deadline: {date}'**
  String deadlinePrefix(String date);

  /// No due date label
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No deadline specified text
  ///
  /// In en, this message translates to:
  /// **'No specific deadline set'**
  String get noDueDateSpecified;

  /// Max score points display
  ///
  /// In en, this message translates to:
  /// **'{score} Points'**
  String maxScorePoints(String score);

  /// Teacher assignment stats
  ///
  /// In en, this message translates to:
  /// **'Submissions: {submissions} | Reviewed: {reviewed}'**
  String teacherAssignmentStats(String submissions, String reviewed);

  /// Pending review status
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// Past due status
  ///
  /// In en, this message translates to:
  /// **'Past Due'**
  String get pastDue;

  /// Action required status
  ///
  /// In en, this message translates to:
  /// **'Submission Required'**
  String get actionRequired;

  /// Attempt number label
  ///
  /// In en, this message translates to:
  /// **'Attempt #{number}'**
  String attemptNumberLabel(String number);

  /// Attached files count
  ///
  /// In en, this message translates to:
  /// **'{count} attached files'**
  String attachedFilesCount(String count);

  /// My homework screen title
  ///
  /// In en, this message translates to:
  /// **'My Assignments'**
  String get myHomeworkTitle;

  /// No assignments in group empty state subtitle
  ///
  /// In en, this message translates to:
  /// **'No homework assignments due for your groups currently'**
  String get noAssignmentsInGroup;

  /// Filter pending chip
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get filterPendingSubmission;

  /// Filter submitted chip
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get filterSubmitted;

  /// Filter reviewed chip
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get filterReviewed;

  /// No assignments in filter title
  ///
  /// In en, this message translates to:
  /// **'No assignments in this category'**
  String get noAssignmentsInFilter;

  /// No assignments in filter subtitle
  ///
  /// In en, this message translates to:
  /// **'Try switching to another filter to view your homework'**
  String get noAssignmentsInFilterSubtitle;

  /// File pick failed error
  ///
  /// In en, this message translates to:
  /// **'Failed to select files: {error}'**
  String filePickFailed(String error);

  /// Attach file required warning
  ///
  /// In en, this message translates to:
  /// **'Please attach at least one file before submitting'**
  String get attachAtLeastOneFile;

  /// Assignment details screen title
  ///
  /// In en, this message translates to:
  /// **'Assignment Details & Submission'**
  String get assignmentDetailsTitle;

  /// Late submission allowed banner
  ///
  /// In en, this message translates to:
  /// **'Late submission is allowed after deadline'**
  String get lateSubmissionAllowedNotice;

  /// Instructions card title
  ///
  /// In en, this message translates to:
  /// **'Instructions & Required Problems'**
  String get instructionsAndProblemsTitle;

  /// Submission status card title
  ///
  /// In en, this message translates to:
  /// **'Your Submission Status'**
  String get submissionStatusCardTitle;

  /// Grade score display
  ///
  /// In en, this message translates to:
  /// **'Score: {score} / {maxScore}'**
  String gradeScorePrefix(String score, String maxScore);

  /// Submitted at date attempt
  ///
  /// In en, this message translates to:
  /// **'Submitted: {date} (Attempt #{attempt})'**
  String submittedAtDateAttempt(String date, String attempt);

  /// Teacher feedback header
  ///
  /// In en, this message translates to:
  /// **'Teacher\'s Feedback:'**
  String get teacherFeedbackTitle;

  /// Resubmit title
  ///
  /// In en, this message translates to:
  /// **'Resubmit (New Attempt)'**
  String get resubmitNewAttemptTitle;

  /// Upload solution files title
  ///
  /// In en, this message translates to:
  /// **'Upload Solution Files'**
  String get uploadSolutionFilesTitle;

  /// Select files button
  ///
  /// In en, this message translates to:
  /// **'Select Files'**
  String get selectFilesBtn;

  /// Tap to pick files box label
  ///
  /// In en, this message translates to:
  /// **'Tap to select answer files (PDF or Images)'**
  String get tapToPickFilesHint;

  /// Max file size notice
  ///
  /// In en, this message translates to:
  /// **'Maximum file size: 20 MB'**
  String get maxFileSizeNotice;

  /// Submit new attempt button
  ///
  /// In en, this message translates to:
  /// **'Submit New Attempt'**
  String get submitNewAttemptBtn;

  /// Submit assignment now button
  ///
  /// In en, this message translates to:
  /// **'Submit Assignment Now'**
  String get submitAssignmentNowBtn;

  /// Deadline passed warning
  ///
  /// In en, this message translates to:
  /// **'The submission deadline has passed and late submissions are not allowed.'**
  String get deadlinePassedNoLateNotice;

  /// Create new assignment sheet title
  ///
  /// In en, this message translates to:
  /// **'Create New Assignment'**
  String get createNewAssignment;

  /// Assignment title field label
  ///
  /// In en, this message translates to:
  /// **'Assignment Title *'**
  String get assignmentTitleField;

  /// Assignment title hint
  ///
  /// In en, this message translates to:
  /// **'e.g., Quadratic Equations Practice'**
  String get assignmentTitleHint;

  /// Assignment title required error
  ///
  /// In en, this message translates to:
  /// **'Please enter assignment title'**
  String get assignmentTitleRequired;

  /// Instructions field label
  ///
  /// In en, this message translates to:
  /// **'Instructions & Guidelines for Students'**
  String get instructionsField;

  /// Instructions hint
  ///
  /// In en, this message translates to:
  /// **'Write the problems or instructions to follow...'**
  String get instructionsHint;

  /// Required field validation message
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// Submission due date button label
  ///
  /// In en, this message translates to:
  /// **'Submission Due Date'**
  String get submissionDueDateField;

  /// Allow late submission switch title
  ///
  /// In en, this message translates to:
  /// **'Allow Late Submission'**
  String get allowLateSubmission;

  /// Allow late submission switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Students can submit even after the deadline has passed'**
  String get allowLateSubmissionSubtitle;

  /// Publish assignment button
  ///
  /// In en, this message translates to:
  /// **'Publish Assignment'**
  String get publishAssignmentBtn;

  /// Assignment published toast
  ///
  /// In en, this message translates to:
  /// **'Assignment created and published successfully'**
  String get assignmentPublishedSuccess;

  /// Submissions header counter
  ///
  /// In en, this message translates to:
  /// **'Submissions ({submissions}) • Graded ({reviewed})'**
  String submissionsCountWithReviewed(String submissions, String reviewed);

  /// No submissions yet empty title
  ///
  /// In en, this message translates to:
  /// **'No submissions yet'**
  String get noSubmissionsYetTitle;

  /// No submissions yet empty subtitle
  ///
  /// In en, this message translates to:
  /// **'Students who submit this homework will appear here'**
  String get noSubmissionsYetSubtitle;

  /// Manage assignments screen title
  ///
  /// In en, this message translates to:
  /// **'Manage Assignments'**
  String get manageAssignmentsTitle;

  /// Group assignments screen title
  ///
  /// In en, this message translates to:
  /// **'Assignments: {groupName}'**
  String groupAssignmentsTitle(String groupName);

  /// Create assignment FAB
  ///
  /// In en, this message translates to:
  /// **'Create Assignment'**
  String get createAssignmentFab;

  /// No assignments for group title
  ///
  /// In en, this message translates to:
  /// **'No assignments added for this group'**
  String get noAssignmentsForGroupTitle;

  /// No assignments for group subtitle
  ///
  /// In en, this message translates to:
  /// **'Start by creating the first assignment for students to track and grade their work'**
  String get noAssignmentsForGroupSubtitle;

  /// Create first assignment button
  ///
  /// In en, this message translates to:
  /// **'Create First Assignment'**
  String get createFirstAssignmentBtn;

  /// File open error toast
  ///
  /// In en, this message translates to:
  /// **'Unable to open file right now'**
  String get fileOpenFailed;

  /// Secure file URL notice
  ///
  /// In en, this message translates to:
  /// **'Secure File URL (valid for 1 hour):'**
  String get secureFileUrlNotice;

  /// Close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeBtn;

  /// Student submitted at date
  ///
  /// In en, this message translates to:
  /// **'Submitted At: {date}'**
  String studentSubmittedAt(String date);

  /// Student attempt number
  ///
  /// In en, this message translates to:
  /// **'Attempt #{number}'**
  String studentAttemptNumber(String number);

  /// Attached files section title
  ///
  /// In en, this message translates to:
  /// **'Student Attached Files'**
  String get attachedFilesTitle;

  /// No files uploaded notice
  ///
  /// In en, this message translates to:
  /// **'The student did not attach any files with this submission'**
  String get noFilesUploadedNotice;

  /// View file action tooltip
  ///
  /// In en, this message translates to:
  /// **'View File'**
  String get viewFileTooltip;

  /// Grading section header
  ///
  /// In en, this message translates to:
  /// **'Enter Score & Feedback'**
  String get gradingSectionTitle;

  /// Score field label
  ///
  /// In en, this message translates to:
  /// **'Earned Score (out of {maxScore})'**
  String scoreFieldLabel(String maxScore);

  /// Score field hint
  ///
  /// In en, this message translates to:
  /// **'e.g., 85'**
  String get scoreFieldHint;

  /// Score required error
  ///
  /// In en, this message translates to:
  /// **'Please enter the score'**
  String get scoreFieldRequired;

  /// Score integer error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid integer'**
  String get scoreMustBeInteger;

  /// Score range error
  ///
  /// In en, this message translates to:
  /// **'Score must be between 0 and {maxScore}'**
  String scoreRangeError(String maxScore);

  /// Teacher feedback field label
  ///
  /// In en, this message translates to:
  /// **'Teacher Feedback & Guidance (Optional)'**
  String get teacherFeedbackField;

  /// Teacher feedback hint
  ///
  /// In en, this message translates to:
  /// **'Add strengths and areas for improvement...'**
  String get teacherFeedbackHint;

  /// Save grade button
  ///
  /// In en, this message translates to:
  /// **'Save Grade & Notify Student'**
  String get saveGradeAndNotifyBtn;

  /// Default initial for student avatar
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get studentInitialDefault;

  /// Present status label
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attendanceStatusPresent;

  /// Absent status label
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attendanceStatusAbsent;

  /// Late status label
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attendanceStatusLate;

  /// Excused status label
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get attendanceStatusExcused;

  /// Completed lecture watch label
  ///
  /// In en, this message translates to:
  /// **'Completed lecture watch (100% • Present)'**
  String get attendanceRateFull;

  /// Watching in progress label
  ///
  /// In en, this message translates to:
  /// **'Watching in progress (Partial attendance • 45%)'**
  String get attendanceRatePartial;

  /// Did not watch lecture yet label
  ///
  /// In en, this message translates to:
  /// **'Did not watch lecture yet (Absent)'**
  String get attendanceRateNone;

  /// Excused lecture watch label
  ///
  /// In en, this message translates to:
  /// **'Excused / Approved exception'**
  String get attendanceRateExcused;

  /// Attendance history screen title
  ///
  /// In en, this message translates to:
  /// **'Attendance Record'**
  String get attendanceHistoryTitle;

  /// Empty attendance records message
  ///
  /// In en, this message translates to:
  /// **'No attendance records\nNo attendance or absence has been recorded for you yet.'**
  String get noAttendanceRecordsMessage;

  /// Previous sessions section title
  ///
  /// In en, this message translates to:
  /// **'Previous Sessions Record'**
  String get previousSessionsTitle;

  /// Total sessions count
  ///
  /// In en, this message translates to:
  /// **'Total {count} sessions'**
  String totalSessionsCount(int count);

  /// Attendance commitment rate label
  ///
  /// In en, this message translates to:
  /// **'Attendance Commitment Rate'**
  String get attendanceCommitmentRate;

  /// High attendance commitment note
  ///
  /// In en, this message translates to:
  /// **'Excellent! Your attendance commitment is outstanding.'**
  String get highAttendanceNote;

  /// Medium attendance commitment note
  ///
  /// In en, this message translates to:
  /// **'Good, please make sure not to repeat absences.'**
  String get mediumAttendanceNote;

  /// Low attendance commitment note
  ///
  /// In en, this message translates to:
  /// **'Warning: Your attendance rate is low, consult your teacher.'**
  String get lowAttendanceNote;

  /// Excellent attendance no absence empty message
  ///
  /// In en, this message translates to:
  /// **'Excellent record! No absences recorded 👏'**
  String get excellentAttendanceNoAbsence;

  /// No sessions match filter empty message
  ///
  /// In en, this message translates to:
  /// **'No sessions match the selected filter'**
  String get noSessionsMatchFilter;

  /// View all sessions button
  ///
  /// In en, this message translates to:
  /// **'View All Sessions'**
  String get viewAllSessionsAction;

  /// Group with colon label
  ///
  /// In en, this message translates to:
  /// **'Group: {groupName}'**
  String groupWithColon(String groupName);

  /// Note with colon label
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String noteWithColon(String note);

  /// Take attendance page title
  ///
  /// In en, this message translates to:
  /// **'Lecture Attendance Monitoring'**
  String get takeAttendanceTitle;

  /// Recorded lectures tracking badge
  ///
  /// In en, this message translates to:
  /// **'🎥 Recorded Lectures Engagement'**
  String get recordedLecturesTrackingBadge;

  /// Take attendance page subtitle
  ///
  /// In en, this message translates to:
  /// **'Monitor student completion of recorded lectures and academic commitment rates'**
  String get takeAttendanceSubtitle;

  /// Refresh attendance sheet tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh Watch Records'**
  String get refreshAttendanceSheetTooltip;

  /// Select recorded lecture sheet title
  ///
  /// In en, this message translates to:
  /// **'Select Recorded Lecture'**
  String get selectRecordedLectureTitle;

  /// Study group dropdown label
  ///
  /// In en, this message translates to:
  /// **'Study Group'**
  String get studyGroupLabel;

  /// Loading groups placeholder
  ///
  /// In en, this message translates to:
  /// **'Loading groups...'**
  String get loadingGroups;

  /// Previous lecture tooltip
  ///
  /// In en, this message translates to:
  /// **'Previous Lecture'**
  String get prevLectureTooltip;

  /// Next lecture tooltip
  ///
  /// In en, this message translates to:
  /// **'Next Lecture'**
  String get nextLectureTooltip;

  /// Pick specific date tooltip
  ///
  /// In en, this message translates to:
  /// **'Pick Specific Date'**
  String get pickDateTooltip;

  /// Jump to today tooltip
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todaySessionTooltip;

  /// Previous day tooltip
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get prevDayTooltip;

  /// Next day tooltip
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDayTooltip;

  /// Session date subtitle
  ///
  /// In en, this message translates to:
  /// **'Attendance session date • Tap to change'**
  String get sessionDateSubtitle;

  /// Select group empty message
  ///
  /// In en, this message translates to:
  /// **'Select a Study Group\nPlease choose a group from the list above to view students and monitor lecture completion.'**
  String get selectGroupToViewAttendanceMessage;

  /// No students in group empty message
  ///
  /// In en, this message translates to:
  /// **'No students in this group\nNo active students have been added to this group yet.'**
  String get noStudentsInGroupMessage;

  /// Attended lecture stat card title
  ///
  /// In en, this message translates to:
  /// **'Completed (Present)'**
  String get attendedLectureTitle;

  /// Completed watch stat card subtitle
  ///
  /// In en, this message translates to:
  /// **'Completed watching ({count} students)'**
  String completedWatchSubtitle(int count);

  /// Not watched yet stat card title
  ///
  /// In en, this message translates to:
  /// **'Not Watched (Absent)'**
  String get notWatchedYetTitle;

  /// Absent from lecture stat card subtitle
  ///
  /// In en, this message translates to:
  /// **'Has not started watching'**
  String get absentFromLectureSubtitle;

  /// Watching in progress stat card title
  ///
  /// In en, this message translates to:
  /// **'Watching in Progress'**
  String get inProgressWatchTitle;

  /// Partial watch stat card subtitle
  ///
  /// In en, this message translates to:
  /// **'Partial watch'**
  String get partialWatchSubtitle;

  /// Attendance rate stat card title
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get attendanceRateTitle;

  /// Group commitment rate stat card subtitle
  ///
  /// In en, this message translates to:
  /// **'Watch commitment rate'**
  String get groupCommitmentRateSubtitle;

  /// Search student or phone hint
  ///
  /// In en, this message translates to:
  /// **'Quick search by student name or phone...'**
  String get searchStudentOrPhoneHint;

  /// No students match filter message
  ///
  /// In en, this message translates to:
  /// **'No students match your search or filter'**
  String get noStudentsMatchFilterMessage;

  /// Reset filters action button
  ///
  /// In en, this message translates to:
  /// **'Reset Filters'**
  String get resetFiltersAction;

  /// Note for student dialog title
  ///
  /// In en, this message translates to:
  /// **'Note for Student: {name}'**
  String noteForStudentTitle(String name);

  /// Attendance note field hint
  ///
  /// In en, this message translates to:
  /// **'Write a note (e.g., excused late, left early...)'**
  String get attendanceNoteHint;

  /// Filter chip all with count
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String filterAllCount(int count);

  /// Filter chip present with count
  ///
  /// In en, this message translates to:
  /// **'Present ({count})'**
  String filterPresentCount(int count);

  /// Filter chip absent with count
  ///
  /// In en, this message translates to:
  /// **'Absent ({count})'**
  String filterAbsentCount(int count);

  /// Filter chip late with count
  ///
  /// In en, this message translates to:
  /// **'Late ({count})'**
  String filterLateCount(int count);

  /// Filter chip excused with count
  ///
  /// In en, this message translates to:
  /// **'Excused ({count})'**
  String filterExcusedCount(int count);

  /// Empty groups filter bar description
  ///
  /// In en, this message translates to:
  /// **'No study groups created yet. Create a group first to get started.'**
  String get noGroupsCreatedYetDesc;

  /// Group colon label
  ///
  /// In en, this message translates to:
  /// **'Group:'**
  String get groupColonLabel;

  /// Settings page title
  ///
  /// In en, this message translates to:
  /// **'Platform & Academy Settings'**
  String get settingsTitle;

  /// Settings page subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage your academy profile, academic contact info, and language preferences'**
  String get settingsSubtitle;

  /// Settings academy section header
  ///
  /// In en, this message translates to:
  /// **'Academy & Platform Profile'**
  String get settingsAcademySection;

  /// Settings academy name label
  ///
  /// In en, this message translates to:
  /// **'Platform Name'**
  String get settingsAcademyNameLabel;

  /// Settings subject label
  ///
  /// In en, this message translates to:
  /// **'Specialization & Track'**
  String get settingsSubjectLabel;

  /// Settings tagline label
  ///
  /// In en, this message translates to:
  /// **'Academic Tagline'**
  String get settingsTaglineLabel;

  /// Settings support phone label
  ///
  /// In en, this message translates to:
  /// **'Support & WhatsApp Phone'**
  String get settingsSupportPhoneLabel;

  /// Settings support email label
  ///
  /// In en, this message translates to:
  /// **'Support Email'**
  String get settingsSupportEmailLabel;

  /// Settings language section header
  ///
  /// In en, this message translates to:
  /// **'Platform Language'**
  String get settingsLanguageSection;

  /// Settings language description
  ///
  /// In en, this message translates to:
  /// **'Choose the primary display language for the platform interface'**
  String get settingsLanguageDesc;

  /// Arabic language option
  ///
  /// In en, this message translates to:
  /// **'العربية (Arabic)'**
  String get settingsLangArabic;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLangEnglish;

  /// Settings account section header
  ///
  /// In en, this message translates to:
  /// **'Teacher Account & Security'**
  String get settingsAccountSection;

  /// Settings teacher name label
  ///
  /// In en, this message translates to:
  /// **'Teacher Name'**
  String get settingsTeacherNameLabel;

  /// Settings teacher email label
  ///
  /// In en, this message translates to:
  /// **'Login Email'**
  String get settingsTeacherEmailLabel;

  /// Change password button
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get settingsChangePasswordBtn;

  /// Sign out button
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOutBtn;

  /// Settings saved toast
  ///
  /// In en, this message translates to:
  /// **'Settings updated successfully'**
  String get settingsSavedSuccess;

  /// Settings dashboard card title
  ///
  /// In en, this message translates to:
  /// **'Platform & Academy Settings'**
  String get settingsServiceCardTitle;

  /// Settings dashboard card description
  ///
  /// In en, this message translates to:
  /// **'Academy profile, WhatsApp support, and language'**
  String get settingsServiceCardDesc;

  /// Notice in create content dialog for video items
  ///
  /// In en, this message translates to:
  /// **'Video files will be uploaded and streamed via high-speed Bunny Stream CDN after creating the item using the \'Upload Video\' action.'**
  String get videoStreamingNotice;

  /// Notice while uploading file
  ///
  /// In en, this message translates to:
  /// **'Uploading file to cloud storage...'**
  String get uploadingFileKeepPageOpen;

  /// Warning not to close page during file upload
  ///
  /// In en, this message translates to:
  /// **'Please keep this page open until the upload is completely finished.'**
  String get doNotClosePageWarning;

  /// Warning not to close page during video upload
  ///
  /// In en, this message translates to:
  /// **'Video is being uploaded and encrypted on the CDN. Please stay on this page until upload reaches 100%.'**
  String get videoUploadDoNotCloseWarning;

  /// No description provided for @sequentialLearningSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sequential Learning & Exams'**
  String get sequentialLearningSectionTitle;

  /// No description provided for @associatedExamBadge.
  ///
  /// In en, this message translates to:
  /// **'Associated Exam (Lesson Quiz)'**
  String get associatedExamBadge;

  /// No description provided for @associatedExamLabel.
  ///
  /// In en, this message translates to:
  /// **'Associated Exam (Lesson Quiz)'**
  String get associatedExamLabel;

  /// No description provided for @associatedExamTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Associated Exam: {title}'**
  String associatedExamTitleLabel(String title);

  /// No description provided for @associatedExamHint.
  ///
  /// In en, this message translates to:
  /// **'Select an exam for this lesson'**
  String get associatedExamHint;

  /// No description provided for @prerequisiteExamLabel.
  ///
  /// In en, this message translates to:
  /// **'Prerequisite Exam (Lock Lesson)'**
  String get prerequisiteExamLabel;

  /// No description provided for @prerequisiteExamHint.
  ///
  /// In en, this message translates to:
  /// **'Select an exam that must be passed first'**
  String get prerequisiteExamHint;

  /// No description provided for @noneOption.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneOption;

  /// No description provided for @totalPointsSummary.
  ///
  /// In en, this message translates to:
  /// **'Total: {points} / {maxScore} pts'**
  String totalPointsSummary(int points, int maxScore);

  /// No description provided for @autoAdjustMaxScore.
  ///
  /// In en, this message translates to:
  /// **'Auto-adjust max score'**
  String autoAdjustMaxScore(int points);

  /// No description provided for @removeOption.
  ///
  /// In en, this message translates to:
  /// **'Remove Option'**
  String get removeOption;

  /// No description provided for @selectCorrectAnswerPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select the correct answer'**
  String get selectCorrectAnswerPrompt;

  /// No description provided for @correctAnswerBadge.
  ///
  /// In en, this message translates to:
  /// **'Correct Answer'**
  String get correctAnswerBadge;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get addOption;

  /// No description provided for @optionLetter.
  ///
  /// In en, this message translates to:
  /// **'Option {letter}'**
  String optionLetter(String letter);

  /// No description provided for @searchExamsHint.
  ///
  /// In en, this message translates to:
  /// **'Search exams...'**
  String get searchExamsHint;

  /// No description provided for @clearSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Clear Search'**
  String get clearSearchAction;

  /// No description provided for @filterAllExams.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String filterAllExams(int count);

  /// No description provided for @filterPublishedExams.
  ///
  /// In en, this message translates to:
  /// **'Published ({count})'**
  String filterPublishedExams(int count);

  /// No description provided for @filterDraftExams.
  ///
  /// In en, this message translates to:
  /// **'Drafts ({count})'**
  String filterDraftExams(int count);

  /// No description provided for @noMatchingExamsFound.
  ///
  /// In en, this message translates to:
  /// **'No exams found matching your criteria'**
  String get noMatchingExamsFound;

  /// No description provided for @teacherPreviewMode.
  ///
  /// In en, this message translates to:
  /// **'Teacher Preview Mode'**
  String get teacherPreviewMode;

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'Remaining: {time}'**
  String remainingTime(String time);

  /// No description provided for @restartLesson.
  ///
  /// In en, this message translates to:
  /// **'Restart Lesson'**
  String get restartLesson;

  /// No description provided for @clickToSeek.
  ///
  /// In en, this message translates to:
  /// **'Click to Seek'**
  String get clickToSeek;

  /// No description provided for @lessonCompletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Lesson Completed!'**
  String get lessonCompletedSuccess;

  /// No description provided for @progressSavedAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Progress saved automatically'**
  String get progressSavedAutomatically;

  /// No description provided for @takeRequiredExamAction.
  ///
  /// In en, this message translates to:
  /// **'Take Required Exam'**
  String get takeRequiredExamAction;

  /// No description provided for @attachedLessonMaterial.
  ///
  /// In en, this message translates to:
  /// **'Attached Material'**
  String get attachedLessonMaterial;

  /// No description provided for @attachedLessonMaterialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download PDF material'**
  String get attachedLessonMaterialSubtitle;

  /// No description provided for @viewAttachedPdf.
  ///
  /// In en, this message translates to:
  /// **'View PDF'**
  String get viewAttachedPdf;

  /// No description provided for @attachPdfToLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Attach PDF'**
  String get attachPdfToLessonAction;

  /// No description provided for @noAttachedMaterialForLesson.
  ///
  /// In en, this message translates to:
  /// **'No material attached'**
  String get noAttachedMaterialForLesson;

  /// No description provided for @videoUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get videoUnmute;

  /// No description provided for @videoMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get videoMute;

  /// No description provided for @videoSourceBadgeYouTube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get videoSourceBadgeYouTube;

  /// No description provided for @invalidYoutubeUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid YouTube URL'**
  String get invalidYoutubeUrl;

  /// No description provided for @videoLinkedSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Video Linked Successfully'**
  String get videoLinkedSuccessToast;

  /// No description provided for @youtubeTabTitle.
  ///
  /// In en, this message translates to:
  /// **'YouTube Video'**
  String get youtubeTabTitle;

  /// No description provided for @bunnyTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Bunny CDN'**
  String get bunnyTabTitle;

  /// No description provided for @youtubeUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'YouTube Video URL'**
  String get youtubeUrlLabel;

  /// No description provided for @youtubeUrlHint.
  ///
  /// In en, this message translates to:
  /// **'Paste YouTube link e.g. https://youtu.be/...'**
  String get youtubeUrlHint;

  /// No description provided for @youtubeUnlistedAdvice.
  ///
  /// In en, this message translates to:
  /// **'Use Unlisted videos for privacy'**
  String get youtubeUnlistedAdvice;

  /// No description provided for @linkVideoAction.
  ///
  /// In en, this message translates to:
  /// **'Link Video'**
  String get linkVideoAction;

  /// No description provided for @noVideosInBankDesc.
  ///
  /// In en, this message translates to:
  /// **'No videos uploaded to the bank yet.'**
  String get noVideosInBankDesc;

  /// No description provided for @addVideoToBankAction.
  ///
  /// In en, this message translates to:
  /// **'Add Video to Bank'**
  String get addVideoToBankAction;

  /// No description provided for @unassignedBadge.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassignedBadge;

  /// No description provided for @assignToGroupsAction.
  ///
  /// In en, this message translates to:
  /// **'Assign to Groups'**
  String get assignToGroupsAction;

  /// No description provided for @lessonPrerequisiteLocked.
  ///
  /// In en, this message translates to:
  /// **'Lesson Locked by Prerequisite'**
  String get lessonPrerequisiteLocked;

  /// No description provided for @mustPassExamToUnlock.
  ///
  /// In en, this message translates to:
  /// **'You must score at least {score}% on {title} to unlock this.'**
  String mustPassExamToUnlock(String title, int score);

  /// No description provided for @prerequisiteExamBadge.
  ///
  /// In en, this message translates to:
  /// **'Prerequisite'**
  String get prerequisiteExamBadge;

  /// No description provided for @videoMaterialPdfBadge.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get videoMaterialPdfBadge;

  /// No description provided for @videoReadyBadge.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get videoReadyBadge;

  /// No description provided for @videoFailedBadge.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get videoFailedBadge;

  /// No description provided for @videoProcessingBadge.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get videoProcessingBadge;

  /// No description provided for @contentSecurityDisclaimerStudent.
  ///
  /// In en, this message translates to:
  /// **'Your progress and activity are being monitored. Please do not share access.'**
  String get contentSecurityDisclaimerStudent;

  /// No description provided for @quickAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Access'**
  String get quickAccessTitle;

  /// No description provided for @quickAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Jump right into your active groups'**
  String get quickAccessSubtitle;

  /// No description provided for @myStudyMaterials.
  ///
  /// In en, this message translates to:
  /// **'My Study Materials'**
  String get myStudyMaterials;

  /// No description provided for @myStudyMaterialsDesc.
  ///
  /// In en, this message translates to:
  /// **'Access all your assigned groups and content'**
  String get myStudyMaterialsDesc;

  /// No description provided for @academicMomentumTitle.
  ///
  /// In en, this message translates to:
  /// **'Academic Momentum'**
  String get academicMomentumTitle;

  /// No description provided for @statExamAverage.
  ///
  /// In en, this message translates to:
  /// **'Exam Average'**
  String get statExamAverage;

  /// No description provided for @statAssignmentsDone.
  ///
  /// In en, this message translates to:
  /// **'Assignments Done'**
  String get statAssignmentsDone;

  /// No description provided for @statVideoProgress.
  ///
  /// In en, this message translates to:
  /// **'Video Progress'**
  String get statVideoProgress;

  /// No description provided for @continueLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get continueLearningTitle;

  /// No description provided for @resumeAtTime.
  ///
  /// In en, this message translates to:
  /// **'Resume at {time}'**
  String resumeAtTime(String time);

  /// No description provided for @lectureCompletedPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Completed'**
  String lectureCompletedPercent(String percent);

  /// No description provided for @resumeNow.
  ///
  /// In en, this message translates to:
  /// **'Resume Now'**
  String get resumeNow;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @dueInHours.
  ///
  /// In en, this message translates to:
  /// **'Due in {hours}h'**
  String dueInHours(int hours);

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due Tomorrow'**
  String get dueTomorrow;

  /// No description provided for @dueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days}d'**
  String dueInDays(int days);

  /// No description provided for @noUrgentTasks.
  ///
  /// In en, this message translates to:
  /// **'No Urgent Tasks'**
  String get noUrgentTasks;

  /// No description provided for @noUrgentTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get noUrgentTasksSubtitle;

  /// No description provided for @urgentTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Urgent Tasks'**
  String get urgentTasksTitle;

  /// No description provided for @urgentTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requires your immediate attention'**
  String get urgentTasksSubtitle;

  /// No description provided for @taskTypeAssignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get taskTypeAssignment;

  /// No description provided for @taskTypeExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get taskTypeExam;

  /// No description provided for @atLeastTwoOptionsRequired.
  ///
  /// In en, this message translates to:
  /// **'At least two options required'**
  String get atLeastTwoOptionsRequired;

  /// No description provided for @examPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish exam: {error}'**
  String examPublishFailed(String error);

  /// No description provided for @totalQuestionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} Questions'**
  String totalQuestionsSummary(int count);

  /// No description provided for @attachVideoMaterialNotice.
  ///
  /// In en, this message translates to:
  /// **'Attach a PDF or Notes to this video.'**
  String get attachVideoMaterialNotice;

  /// No description provided for @attachVideoMaterialHint.
  ///
  /// In en, this message translates to:
  /// **'Select a PDF file'**
  String get attachVideoMaterialHint;

  /// No description provided for @addNewMaterialTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Material'**
  String get addNewMaterialTitle;

  /// No description provided for @uploadBunnyVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Video'**
  String get uploadBunnyVideoTitle;

  /// No description provided for @uploadBunnyVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload directly to Bunny CDN'**
  String get uploadBunnyVideoSubtitle;

  /// No description provided for @uploadPdfFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get uploadPdfFileTitle;

  /// No description provided for @uploadPdfFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload documents and notes'**
  String get uploadPdfFileSubtitle;

  /// No description provided for @imagesCategory.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get imagesCategory;

  /// No description provided for @createAssignmentShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create Assignment'**
  String get createAssignmentShortcut;

  /// No description provided for @createAssignmentShortcutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a new assignment task'**
  String get createAssignmentShortcutSubtitle;

  /// No description provided for @createExamShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create Exam'**
  String get createExamShortcut;

  /// No description provided for @createExamShortcutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a new quiz or exam'**
  String get createExamShortcutSubtitle;

  /// No description provided for @videosCategory.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videosCategory;

  /// No description provided for @pdfDocumentsCategory.
  ///
  /// In en, this message translates to:
  /// **'PDF Documents'**
  String get pdfDocumentsCategory;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @filterAssignmentsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Assignments ({count})'**
  String filterAssignmentsWithCount(int count);

  /// No description provided for @filterExamsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Exams ({count})'**
  String filterExamsWithCount(int count);

  /// No description provided for @noVideosInCategory.
  ///
  /// In en, this message translates to:
  /// **'No videos found in this category.'**
  String get noVideosInCategory;

  /// No description provided for @uploadFirstVideoAction.
  ///
  /// In en, this message translates to:
  /// **'Upload First Video'**
  String get uploadFirstVideoAction;

  /// No description provided for @noPdfsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No PDFs found in this category.'**
  String get noPdfsInCategory;

  /// No description provided for @uploadFirstPdfAction.
  ///
  /// In en, this message translates to:
  /// **'Upload First PDF'**
  String get uploadFirstPdfAction;

  /// No description provided for @noAssignmentsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No assignments found in this category.'**
  String get noAssignmentsInCategory;

  /// No description provided for @createFirstAssignmentAction.
  ///
  /// In en, this message translates to:
  /// **'Create First Assignment'**
  String get createFirstAssignmentAction;

  /// No description provided for @noExamsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No exams found in this category.'**
  String get noExamsInCategory;

  /// No description provided for @createFirstExamAction.
  ///
  /// In en, this message translates to:
  /// **'Create First Exam'**
  String get createFirstExamAction;

  /// No description provided for @videoBankTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Bank'**
  String get videoBankTitle;

  /// No description provided for @videoBankSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage all your uploaded videos'**
  String get videoBankSubtitle;

  /// No description provided for @totalVideosCount.
  ///
  /// In en, this message translates to:
  /// **'Total ({count})'**
  String totalVideosCount(int count);

  /// No description provided for @assignedVideosCount.
  ///
  /// In en, this message translates to:
  /// **'Assigned ({count})'**
  String assignedVideosCount(int count);

  /// No description provided for @unassignedVideosCount.
  ///
  /// In en, this message translates to:
  /// **'Unassigned ({count})'**
  String unassignedVideosCount(int count);

  /// No description provided for @filterAllVideos.
  ///
  /// In en, this message translates to:
  /// **'All Videos ({count})'**
  String filterAllVideos(int count);

  /// No description provided for @filterUnassignedOnly.
  ///
  /// In en, this message translates to:
  /// **'Unassigned Only ({count})'**
  String filterUnassignedOnly(int count);

  /// No description provided for @noVideosInBankTitle.
  ///
  /// In en, this message translates to:
  /// **'No Videos Yet'**
  String get noVideosInBankTitle;

  /// No description provided for @studentNavDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress & tasks'**
  String get studentNavDashboardSubtitle;

  /// No description provided for @studentNavNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recent updates'**
  String get studentNavNotificationsSubtitle;

  /// No description provided for @studentNavContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Videos & lessons'**
  String get studentNavContentSubtitle;

  /// No description provided for @studentNavAssignmentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Homework tasks'**
  String get studentNavAssignmentsSubtitle;

  /// No description provided for @studentNavExamsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quizzes & results'**
  String get studentNavExamsSubtitle;

  /// No description provided for @searchAssignmentsHint.
  ///
  /// In en, this message translates to:
  /// **'Search assignments...'**
  String get searchAssignmentsHint;

  /// No description provided for @filterAllAssignments.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String filterAllAssignments(int count);

  /// No description provided for @filterNeedsGrading.
  ///
  /// In en, this message translates to:
  /// **'Needs Grading'**
  String get filterNeedsGrading;

  /// No description provided for @filterPastDue.
  ///
  /// In en, this message translates to:
  /// **'Past Due'**
  String get filterPastDue;

  /// No description provided for @noMatchingAssignmentsFound.
  ///
  /// In en, this message translates to:
  /// **'No assignments match your search.'**
  String get noMatchingAssignmentsFound;

  /// No description provided for @lecturesRoadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Lectures Roadmap'**
  String get lecturesRoadmapTitle;

  /// No description provided for @lecturesRoadmapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your scheduled lectures'**
  String get lecturesRoadmapSubtitle;

  /// No description provided for @recordedSessionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Recorded Session Available'**
  String get recordedSessionAvailable;

  /// No description provided for @youtubeUnlistedNotice.
  ///
  /// In en, this message translates to:
  /// **'Use Unlisted videos to prevent public access.'**
  String get youtubeUnlistedNotice;

  /// No description provided for @materialAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Material Attachment'**
  String get materialAttachmentTitle;

  /// No description provided for @chooseMaterialFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get chooseMaterialFile;

  /// No description provided for @changePdfFileAction.
  ///
  /// In en, this message translates to:
  /// **'Change PDF'**
  String get changePdfFileAction;

  /// No description provided for @selectTargetGroups.
  ///
  /// In en, this message translates to:
  /// **'Select Target Groups'**
  String get selectTargetGroups;

  /// No description provided for @noGroupsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No groups available'**
  String get noGroupsAvailable;

  /// No description provided for @groupAssignmentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Groups assigned successfully'**
  String get groupAssignmentSuccess;

  /// No description provided for @manageAssignedGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Groups'**
  String get manageAssignedGroupsTitle;

  /// No description provided for @manageAssignedGroupsDesc.
  ///
  /// In en, this message translates to:
  /// **'Select which groups can access this content.'**
  String get manageAssignedGroupsDesc;

  /// No description provided for @saveGroupAssignmentsAction.
  ///
  /// In en, this message translates to:
  /// **'Save Assignments'**
  String get saveGroupAssignmentsAction;

  /// No description provided for @enrolledStudentsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Students Enrolled'**
  String enrolledStudentsCountLabel(int count);

  /// No description provided for @streamingProviderSettingTitle.
  ///
  /// In en, this message translates to:
  /// **'Lecture Streaming Provider'**
  String get streamingProviderSettingTitle;

  /// No description provided for @streamingProviderSettingDesc.
  ///
  /// In en, this message translates to:
  /// **'Select the authorized provider to stream your lectures to students'**
  String get streamingProviderSettingDesc;

  /// No description provided for @providerYoutubeLabel.
  ///
  /// In en, this message translates to:
  /// **'YouTube (Unlisted)'**
  String get providerYoutubeLabel;

  /// No description provided for @providerYoutubeDesc.
  ///
  /// In en, this message translates to:
  /// **'Fast & free hosting with instant linking via video URL'**
  String get providerYoutubeDesc;

  /// No description provided for @providerBunnyLabel.
  ///
  /// In en, this message translates to:
  /// **'Bunny Stream (Private Encrypted CDN)'**
  String get providerBunnyLabel;

  /// No description provided for @providerBunnyDesc.
  ///
  /// In en, this message translates to:
  /// **'High security & anti-download protection with HLS streaming'**
  String get providerBunnyDesc;

  /// No description provided for @providerUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Streaming provider updated successfully'**
  String get providerUpdatedToast;

  /// No description provided for @allInOneStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'All-in-One Lecture Studio'**
  String get allInOneStudioTitle;

  /// No description provided for @allInOneStudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add video, handout, and quiz in a single step'**
  String get allInOneStudioSubtitle;

  /// No description provided for @lectureDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Lecture & Video Details'**
  String get lectureDetailsSection;

  /// No description provided for @lectureTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Lecture Title'**
  String get lectureTitleLabel;

  /// No description provided for @lectureTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Lecture 01 - Intro to Algebra'**
  String get lectureTitleHint;

  /// No description provided for @lectureDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Lecture Description or Notes'**
  String get lectureDescLabel;

  /// No description provided for @lectureDescHint.
  ///
  /// In en, this message translates to:
  /// **'Important points for students beside the video...'**
  String get lectureDescHint;

  /// No description provided for @handoutAttachmentSection.
  ///
  /// In en, this message translates to:
  /// **'Attached Lecture Handout (PDF)'**
  String get handoutAttachmentSection;

  /// No description provided for @attachHandoutPdf.
  ///
  /// In en, this message translates to:
  /// **'Attach Lecture PDF Handout'**
  String get attachHandoutPdf;

  /// No description provided for @handoutSelected.
  ///
  /// In en, this message translates to:
  /// **'File selected: {fileName}'**
  String handoutSelected(String fileName);

  /// No description provided for @inlineQuizSection.
  ///
  /// In en, this message translates to:
  /// **'Lecture Quiz & Unlock Requirement'**
  String get inlineQuizSection;

  /// No description provided for @enableInlineQuiz.
  ///
  /// In en, this message translates to:
  /// **'Enable required quiz to unlock next lecture'**
  String get enableInlineQuiz;

  /// No description provided for @passingScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Passing Score'**
  String get passingScoreLabel;

  /// No description provided for @questionTypeMcq.
  ///
  /// In en, this message translates to:
  /// **'Multiple Choice'**
  String get questionTypeMcq;

  /// No description provided for @optionLabel.
  ///
  /// In en, this message translates to:
  /// **'Option {index}'**
  String optionLabel(int index);

  /// No description provided for @correctOptionBadge.
  ///
  /// In en, this message translates to:
  /// **'Correct Answer'**
  String get correctOptionBadge;

  /// No description provided for @publishAndApproveAction.
  ///
  /// In en, this message translates to:
  /// **'Save & Approve Lecture to Syllabus 🚀'**
  String get publishAndApproveAction;

  /// No description provided for @lectureCreatedSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Lecture & quiz successfully added to syllabus'**
  String get lectureCreatedSuccessToast;

  /// No description provided for @curriculumRoadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Lectures & Curriculum'**
  String get curriculumRoadmapTitle;

  /// No description provided for @curriculumRoadmapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sequential lecture roadmap & quiz gates'**
  String get curriculumRoadmapSubtitle;

  /// No description provided for @lectureNumberBadge.
  ///
  /// In en, this message translates to:
  /// **'Lecture {number}'**
  String lectureNumberBadge(int number);

  /// No description provided for @moveUpAction.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get moveUpAction;

  /// No description provided for @moveDownAction.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get moveDownAction;

  /// No description provided for @quizGateNotice.
  ///
  /// In en, this message translates to:
  /// **'Must pass previous exam'**
  String get quizGateNotice;

  /// No description provided for @quizUnlockedReady.
  ///
  /// In en, this message translates to:
  /// **'🟢 Quiz ready: Start now'**
  String get quizUnlockedReady;

  /// No description provided for @downloadHandoutAction.
  ///
  /// In en, this message translates to:
  /// **'Download Handout (PDF)'**
  String get downloadHandoutAction;

  /// No description provided for @nextLectureLockedNotice.
  ///
  /// In en, this message translates to:
  /// **'🔒 Locked: Requires finishing {prevTitle} and passing its quiz with {score}%'**
  String nextLectureLockedNotice(String prevTitle, int score);

  /// No description provided for @videoCompletedCongrats.
  ///
  /// In en, this message translates to:
  /// **'Well done! You have completed the lecture 🎉 The quiz is now unlocked.'**
  String get videoCompletedCongrats;

  /// No description provided for @takeQuizNowAction.
  ///
  /// In en, this message translates to:
  /// **'Take Lecture Quiz Now 📝'**
  String get takeQuizNowAction;

  /// No description provided for @quizPassedUnlockNext.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You passed the quiz and unlocked the next lecture 🚀'**
  String get quizPassedUnlockNext;

  /// No description provided for @videoSourceYoutube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get videoSourceYoutube;

  /// No description provided for @videoSourceBunny.
  ///
  /// In en, this message translates to:
  /// **'Bunny CDN'**
  String get videoSourceBunny;

  /// No description provided for @videoSourceNone.
  ///
  /// In en, this message translates to:
  /// **'No Video'**
  String get videoSourceNone;

  /// No description provided for @videoSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Video Source'**
  String get videoSourceLabel;

  /// No description provided for @changeVideoFileAction.
  ///
  /// In en, this message translates to:
  /// **'Change Video File'**
  String get changeVideoFileAction;

  /// No description provided for @addMcqQuestionAction.
  ///
  /// In en, this message translates to:
  /// **'Add Multiple Choice Question'**
  String get addMcqQuestionAction;

  /// No description provided for @addTrueFalseQuestionAction.
  ///
  /// In en, this message translates to:
  /// **'Add True / False Question'**
  String get addTrueFalseQuestionAction;

  /// No description provided for @trueOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'True (Correct)'**
  String get trueOptionLabel;

  /// No description provided for @falseOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'False (Incorrect)'**
  String get falseOptionLabel;

  /// No description provided for @completedBadge.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedBadge;

  /// No description provided for @currentActiveLectureBadge.
  ///
  /// In en, this message translates to:
  /// **'Current Lecture'**
  String get currentActiveLectureBadge;

  /// No description provided for @overallCourseProgress.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress: {completed} of {total} lectures completed ({percentage}%)'**
  String overallCourseProgress(int completed, int total, int percentage);

  /// No description provided for @reviewQuizResultAction.
  ///
  /// In en, this message translates to:
  /// **'Review Quiz Score'**
  String get reviewQuizResultAction;

  /// No description provided for @rewatchLectureAction.
  ///
  /// In en, this message translates to:
  /// **'Rewatch Lecture'**
  String get rewatchLectureAction;

  /// No description provided for @startLectureAction.
  ///
  /// In en, this message translates to:
  /// **'Watch Lecture'**
  String get startLectureAction;

  /// No description provided for @quizPrefix.
  ///
  /// In en, this message translates to:
  /// **'Lecture Quiz'**
  String get quizPrefix;

  /// No description provided for @removeQuestionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Question'**
  String get removeQuestionTooltip;

  /// No description provided for @addNewLectureHero.
  ///
  /// In en, this message translates to:
  /// **'Add New All-in-One Lecture'**
  String get addNewLectureHero;

  /// No description provided for @noLecturesInCurriculum.
  ///
  /// In en, this message translates to:
  /// **'No lectures in this curriculum yet'**
  String get noLecturesInCurriculum;

  /// No description provided for @noLecturesInCurriculumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start by adding the first lecture with video, booklet, and quiz'**
  String get noLecturesInCurriculumSubtitle;

  /// No description provided for @quizRulesAtLeastOneQuestion.
  ///
  /// In en, this message translates to:
  /// **'Quiz must contain at least one question'**
  String get quizRulesAtLeastOneQuestion;

  /// No description provided for @questionTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter question text'**
  String get questionTextRequired;

  /// No description provided for @fillAllOptionsNotice.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all options'**
  String get fillAllOptionsNotice;

  /// No description provided for @creatingContent.
  ///
  /// In en, this message translates to:
  /// **'Creating lecture...'**
  String get creatingContent;

  /// No description provided for @linkingYoutubeVideo.
  ///
  /// In en, this message translates to:
  /// **'Linking YouTube video...'**
  String get linkingYoutubeVideo;

  /// No description provided for @uploadingNotice.
  ///
  /// In en, this message translates to:
  /// **'Uploading attached handout...'**
  String get uploadingNotice;

  /// No description provided for @creatingExam.
  ///
  /// In en, this message translates to:
  /// **'Creating lecture quiz...'**
  String get creatingExam;

  /// No description provided for @youtubeUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'YouTube URL is required'**
  String get youtubeUrlRequired;

  /// No description provided for @currentMissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Mission'**
  String get currentMissionTitle;

  /// No description provided for @currentMissionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Resume your academic mastery right where you left off'**
  String get currentMissionSubtitle;

  /// No description provided for @resumeLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Resume Lecture Now'**
  String get resumeLessonAction;

  /// No description provided for @startNextLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Start Next Lecture'**
  String get startNextLessonAction;

  /// No description provided for @allLecturesCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Outstanding! You completed all lectures in this syllabus 🏆'**
  String get allLecturesCompletedTitle;

  /// No description provided for @allLecturesCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You have mastered all syllabus requirements successfully'**
  String get allLecturesCompletedSubtitle;

  /// No description provided for @syllabusViewRoadmap.
  ///
  /// In en, this message translates to:
  /// **'Interactive Roadmap'**
  String get syllabusViewRoadmap;

  /// No description provided for @syllabusViewList.
  ///
  /// In en, this message translates to:
  /// **'Syllabus List'**
  String get syllabusViewList;

  /// No description provided for @estimatedDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String estimatedDurationMinutes(int minutes);

  /// No description provided for @milestoneStationLabel.
  ///
  /// In en, this message translates to:
  /// **'Station {index}'**
  String milestoneStationLabel(int index);

  /// No description provided for @lessonHandoutChip.
  ///
  /// In en, this message translates to:
  /// **'Handout PDF'**
  String get lessonHandoutChip;

  /// No description provided for @lessonQuizChip.
  ///
  /// In en, this message translates to:
  /// **'Lesson Quiz'**
  String get lessonQuizChip;

  /// No description provided for @lockedByPrereqTooltip.
  ///
  /// In en, this message translates to:
  /// **'Locked: Requires passing previous lecture quiz'**
  String get lockedByPrereqTooltip;

  /// No description provided for @groupHandoutPdfLabel.
  ///
  /// In en, this message translates to:
  /// **'Handout PDF for this group'**
  String get groupHandoutPdfLabel;

  /// No description provided for @groupExamLabel.
  ///
  /// In en, this message translates to:
  /// **'Lesson Quiz for this group'**
  String get groupExamLabel;

  /// No description provided for @noExamSelected.
  ///
  /// In en, this message translates to:
  /// **'No quiz (Optional)'**
  String get noExamSelected;

  /// No description provided for @lockUntilPreviousQuizPassed.
  ///
  /// In en, this message translates to:
  /// **'Lock until previous quiz is passed'**
  String get lockUntilPreviousQuizPassed;

  /// No description provided for @sortOrderInGroup.
  ///
  /// In en, this message translates to:
  /// **'Sequence in Group'**
  String get sortOrderInGroup;

  /// No description provided for @customFileSelected.
  ///
  /// In en, this message translates to:
  /// **'Custom Handout: {fileName}'**
  String customFileSelected(String fileName);

  /// No description provided for @pickGroupHandoutAction.
  ///
  /// In en, this message translates to:
  /// **'Upload Group Handout (PDF)'**
  String get pickGroupHandoutAction;

  /// No description provided for @customizeForThisGroup.
  ///
  /// In en, this message translates to:
  /// **'Customize Handout & Quiz for this group'**
  String get customizeForThisGroup;

  /// No description provided for @assignedToCountGroups.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {count} groups'**
  String assignedToCountGroups(int count);

  /// No description provided for @distributeToGroupsAction.
  ///
  /// In en, this message translates to:
  /// **'Distribute to Groups'**
  String get distributeToGroupsAction;

  /// No description provided for @courseProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Progress'**
  String get courseProgressTitle;

  /// No description provided for @noContentYet.
  ///
  /// In en, this message translates to:
  /// **'No content yet'**
  String get noContentYet;

  /// No description provided for @manualUnlockAction.
  ///
  /// In en, this message translates to:
  /// **'Manual Unlock'**
  String get manualUnlockAction;

  /// No description provided for @manualUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual Unlock'**
  String get manualUnlockTitle;

  /// No description provided for @manualUnlockWarningText1.
  ///
  /// In en, this message translates to:
  /// **'You are about to unlock the lesson '**
  String get manualUnlockWarningText1;

  /// No description provided for @manualUnlockWarningText2.
  ///
  /// In en, this message translates to:
  /// **' for the student '**
  String get manualUnlockWarningText2;

  /// No description provided for @manualUnlockWarningText3.
  ///
  /// In en, this message translates to:
  /// **' as an exception without requiring the previous exam. This action will be recorded.'**
  String get manualUnlockWarningText3;

  /// No description provided for @manualUnlockReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (Optional)'**
  String get manualUnlockReasonLabel;

  /// No description provided for @manualUnlockReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Student passed the exam on paper'**
  String get manualUnlockReasonHint;

  /// No description provided for @manualUnlockConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Unlock'**
  String get manualUnlockConfirm;

  /// No description provided for @courseSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Settings'**
  String get courseSettingsTitle;

  /// No description provided for @enforceSequentialLearning.
  ///
  /// In en, this message translates to:
  /// **'Enforce Sequential Learning'**
  String get enforceSequentialLearning;

  /// No description provided for @enforceSequentialLearningDesc.
  ///
  /// In en, this message translates to:
  /// **'Students must pass quizzes to unlock next lessons'**
  String get enforceSequentialLearningDesc;

  /// No description provided for @defaultPassingScore.
  ///
  /// In en, this message translates to:
  /// **'Default Passing Score (%)'**
  String get defaultPassingScore;

  /// No description provided for @passingScoreOverride.
  ///
  /// In en, this message translates to:
  /// **'Passing Score Override (%)'**
  String get passingScoreOverride;

  /// No description provided for @passingScoreDefaultHint.
  ///
  /// In en, this message translates to:
  /// **'Course Default'**
  String get passingScoreDefaultHint;

  /// No description provided for @lessonQuizSequentialRequirement.
  ///
  /// In en, this message translates to:
  /// **'This Lesson Quiz will be required for students to unlock the next lesson (if Sequential Learning is enabled).'**
  String get lessonQuizSequentialRequirement;

  /// No description provided for @videoLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Library'**
  String get videoLibraryTitle;

  /// No description provided for @videoLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create videos once and reuse them across multiple courses.'**
  String get videoLibrarySubtitle;

  /// No description provided for @addVideo.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get addVideo;

  /// No description provided for @filterUsedInCourses.
  ///
  /// In en, this message translates to:
  /// **'Used in Courses'**
  String get filterUsedInCourses;

  /// No description provided for @usedInNCourses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Used in 1 course} other{Used in {count} courses}}'**
  String usedInNCourses(int count);

  /// No description provided for @notUsedInAnyCourse.
  ///
  /// In en, this message translates to:
  /// **'Not used in any course'**
  String get notUsedInAnyCourse;

  /// No description provided for @addToCourse.
  ///
  /// In en, this message translates to:
  /// **'Add to Course'**
  String get addToCourse;

  /// No description provided for @editVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit Video'**
  String get editVideo;

  /// No description provided for @videoAddedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Video added to your library.'**
  String get videoAddedToLibrary;

  /// No description provided for @addToCourseAfterSave.
  ///
  /// In en, this message translates to:
  /// **'Add to Course'**
  String get addToCourseAfterSave;

  /// No description provided for @selectCourse.
  ///
  /// In en, this message translates to:
  /// **'Select Course'**
  String get selectCourse;

  /// No description provided for @selectCourseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which course to add this video to:'**
  String get selectCourseSubtitle;

  /// No description provided for @nCoursesNLessons.
  ///
  /// In en, this message translates to:
  /// **'{lessons} Lessons · {students} Students'**
  String nCoursesNLessons(int lessons, int students);

  /// No description provided for @addLesson.
  ///
  /// In en, this message translates to:
  /// **'Add Lesson'**
  String get addLesson;

  /// No description provided for @addLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Lesson'**
  String get addLessonTitle;

  /// No description provided for @addLessonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How would you like to add this lesson?'**
  String get addLessonSubtitle;

  /// No description provided for @useExistingVideo.
  ///
  /// In en, this message translates to:
  /// **'Use Existing Video'**
  String get useExistingVideo;

  /// No description provided for @useExistingVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a video from your library'**
  String get useExistingVideoSubtitle;

  /// No description provided for @addNewVideoToLesson.
  ///
  /// In en, this message translates to:
  /// **'Add New Video'**
  String get addNewVideoToLesson;

  /// No description provided for @addNewVideoToLessonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new video for this course'**
  String get addNewVideoToLessonSubtitle;

  /// No description provided for @lessonSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson Setup'**
  String get lessonSetupTitle;

  /// No description provided for @studyMaterial.
  ///
  /// In en, this message translates to:
  /// **'Study Material'**
  String get studyMaterial;

  /// No description provided for @uploadPdf.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get uploadPdf;

  /// No description provided for @replacePdf.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replacePdf;

  /// No description provided for @removePdf.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePdf;

  /// No description provided for @lessonQuizLabel.
  ///
  /// In en, this message translates to:
  /// **'Lesson Quiz'**
  String get lessonQuizLabel;

  /// No description provided for @lessonQuizHint.
  ///
  /// In en, this message translates to:
  /// **'Select Lesson Quiz'**
  String get lessonQuizHint;

  /// No description provided for @createLessonQuiz.
  ///
  /// In en, this message translates to:
  /// **'+ Create Lesson Quiz'**
  String get createLessonQuiz;

  /// No description provided for @useCourseDefault.
  ///
  /// In en, this message translates to:
  /// **'Use course default — {score}%'**
  String useCourseDefault(int score);

  /// No description provided for @customPassingScore.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customPassingScore;

  /// No description provided for @lessonAddedToCourse.
  ///
  /// In en, this message translates to:
  /// **'Lesson added to {course}.'**
  String lessonAddedToCourse(String course);

  /// No description provided for @lessonUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Lesson updated successfully.'**
  String get lessonUpdatedSuccess;

  /// No description provided for @manageLessons.
  ///
  /// In en, this message translates to:
  /// **'Manage Lessons'**
  String get manageLessons;

  /// No description provided for @courseBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Builder'**
  String get courseBuilderTitle;

  /// No description provided for @sequentialLearningLabel.
  ///
  /// In en, this message translates to:
  /// **'Sequential Learning'**
  String get sequentialLearningLabel;

  /// No description provided for @sequentialLearningDescription.
  ///
  /// In en, this message translates to:
  /// **'Students must complete each lesson\'s video and pass the lesson quiz before the next lesson becomes available.'**
  String get sequentialLearningDescription;

  /// No description provided for @defaultLessonPassingScore.
  ///
  /// In en, this message translates to:
  /// **'Default Lesson Quiz Passing Score'**
  String get defaultLessonPassingScore;

  /// No description provided for @learningProgression.
  ///
  /// In en, this message translates to:
  /// **'Learning Progression'**
  String get learningProgression;

  /// No description provided for @noLessonsYet.
  ///
  /// In en, this message translates to:
  /// **'No lessons yet'**
  String get noLessonsYet;

  /// No description provided for @noLessonsYetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start building your course by adding a video lesson.'**
  String get noLessonsYetSubtitle;

  /// No description provided for @addFirstLesson.
  ///
  /// In en, this message translates to:
  /// **'Add First Lesson'**
  String get addFirstLesson;

  /// No description provided for @videoPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Video'**
  String get videoPickerTitle;

  /// No description provided for @videoPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search videos...'**
  String get videoPickerSearchHint;

  /// No description provided for @lessonNumber.
  ///
  /// In en, this message translates to:
  /// **'Lesson {n}'**
  String lessonNumber(int n);

  /// No description provided for @hasStudyMaterial.
  ///
  /// In en, this message translates to:
  /// **'Study Material'**
  String get hasStudyMaterial;

  /// No description provided for @hasLessonQuiz.
  ///
  /// In en, this message translates to:
  /// **'Lesson Quiz'**
  String get hasLessonQuiz;

  /// No description provided for @lessonEditorCreateQuiz.
  ///
  /// In en, this message translates to:
  /// **'Create New Quiz'**
  String get lessonEditorCreateQuiz;

  /// No description provided for @editLesson.
  ///
  /// In en, this message translates to:
  /// **'Edit Lesson'**
  String get editLesson;

  /// No description provided for @deleteLesson.
  ///
  /// In en, this message translates to:
  /// **'Delete Lesson'**
  String get deleteLesson;

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragToReorder;

  /// No description provided for @openFullPage.
  ///
  /// In en, this message translates to:
  /// **'Open Full Page'**
  String get openFullPage;

  /// No description provided for @courseSummary.
  ///
  /// In en, this message translates to:
  /// **'Course Summary'**
  String get courseSummary;

  /// No description provided for @selectLessonToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a lesson to edit details or add a new one'**
  String get selectLessonToEdit;

  /// No description provided for @lessonAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Lesson Analytics'**
  String get lessonAnalytics;

  /// No description provided for @backToCourse.
  ///
  /// In en, this message translates to:
  /// **'Back to Course'**
  String get backToCourse;

  /// No description provided for @activeEditing.
  ///
  /// In en, this message translates to:
  /// **'Currently Editing'**
  String get activeEditing;

  /// No description provided for @lessonDetails.
  ///
  /// In en, this message translates to:
  /// **'Lesson Details'**
  String get lessonDetails;

  /// No description provided for @lessonVideo.
  ///
  /// In en, this message translates to:
  /// **'Lesson Video'**
  String get lessonVideo;

  /// No description provided for @lessonHandouts.
  ///
  /// In en, this message translates to:
  /// **'Handouts & Materials'**
  String get lessonHandouts;

  /// No description provided for @lessonQuizSettings.
  ///
  /// In en, this message translates to:
  /// **'Quiz & Passing Score'**
  String get lessonQuizSettings;

  /// No description provided for @nLessonsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 Lesson} other{{count} Lessons}}'**
  String nLessonsCount(int count);

  /// No description provided for @nStudentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 Student} other{{count} Students}}'**
  String nStudentsCount(int count);

  /// No description provided for @duplicateVideoInCourse.
  ///
  /// In en, this message translates to:
  /// **'This video is already part of this course.'**
  String get duplicateVideoInCourse;

  /// No description provided for @couldNotAddLesson.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t add this lesson. Please try again.'**
  String get couldNotAddLesson;

  /// No description provided for @couldNotUpdateLesson.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update this lesson. Please try again.'**
  String get couldNotUpdateLesson;

  /// No description provided for @noCoursesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No courses available.'**
  String get noCoursesAvailable;

  /// No description provided for @noCoursesAvailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a course first, then add videos to it.'**
  String get noCoursesAvailableSubtitle;

  /// No description provided for @videoNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Video not available'**
  String get videoNotAvailable;

  /// No description provided for @allVideosUsed.
  ///
  /// In en, this message translates to:
  /// **'All videos are being used'**
  String get allVideosUsed;

  /// No description provided for @allVideosUsedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All your videos are currently used in at least one course.'**
  String get allVideosUsedSubtitle;

  /// No description provided for @noUnusedVideos.
  ///
  /// In en, this message translates to:
  /// **'No unused videos'**
  String get noUnusedVideos;

  /// No description provided for @videoLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your Video Library is empty'**
  String get videoLibraryEmpty;

  /// No description provided for @videoLibraryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first teaching video and reuse it across your courses.'**
  String get videoLibraryEmptySubtitle;

  /// No description provided for @usedInMoreCourses.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String usedInMoreCourses(int count);

  /// No description provided for @myCoursesTitle.
  ///
  /// In en, this message translates to:
  /// **'My Courses'**
  String get myCoursesTitle;

  /// No description provided for @myCoursesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access all your enrolled courses and track your progress'**
  String get myCoursesSubtitle;

  /// No description provided for @openCourseAction.
  ///
  /// In en, this message translates to:
  /// **'Open Course'**
  String get openCourseAction;

  /// No description provided for @noEnrolledCoursesTitle.
  ///
  /// In en, this message translates to:
  /// **'No courses yet'**
  String get noEnrolledCoursesTitle;

  /// No description provided for @noEnrolledCoursesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your courses will appear here once you are enrolled.'**
  String get noEnrolledCoursesSubtitle;

  /// No description provided for @courseBeingPreparedTitle.
  ///
  /// In en, this message translates to:
  /// **'This course is being prepared.'**
  String get courseBeingPreparedTitle;

  /// No description provided for @courseBeingPreparedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your lessons will appear here soon.'**
  String get courseBeingPreparedSubtitle;

  /// No description provided for @startCourseAction.
  ///
  /// In en, this message translates to:
  /// **'Start Course'**
  String get startCourseAction;

  /// No description provided for @continueLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Continue Lesson'**
  String get continueLessonAction;

  /// No description provided for @takeLessonQuizAction.
  ///
  /// In en, this message translates to:
  /// **'Start Lesson Quiz'**
  String get takeLessonQuizAction;

  /// No description provided for @retryLessonQuizAction.
  ///
  /// In en, this message translates to:
  /// **'Retry Lesson Quiz'**
  String get retryLessonQuizAction;

  /// No description provided for @reviewCourseAction.
  ///
  /// In en, this message translates to:
  /// **'Review Course'**
  String get reviewCourseAction;

  /// No description provided for @reviewLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Review Lesson'**
  String get reviewLessonAction;

  /// No description provided for @continueToNextLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Continue to Next Lesson'**
  String get continueToNextLessonAction;

  /// No description provided for @completeLessonToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Complete Lesson {n} to unlock this lesson.'**
  String completeLessonToUnlock(int n);

  /// No description provided for @availableStatus.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableStatus;

  /// No description provided for @lessonQuizReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your lesson quiz is ready.'**
  String get lessonQuizReadyTitle;

  /// No description provided for @lessonQuizReadyDesc.
  ///
  /// In en, this message translates to:
  /// **'Test your understanding of this lesson to unlock the next one.'**
  String get lessonQuizReadyDesc;

  /// No description provided for @quizNotPassedTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz not passed'**
  String get quizNotPassedTitle;

  /// No description provided for @quizNotPassedDesc.
  ///
  /// In en, this message translates to:
  /// **'You can review the lesson and try again.'**
  String get quizNotPassedDesc;

  /// No description provided for @lessonCompletedCongrats.
  ///
  /// In en, this message translates to:
  /// **'Lesson completed!'**
  String get lessonCompletedCongrats;

  /// No description provided for @passedQuizNotice.
  ///
  /// In en, this message translates to:
  /// **'You passed the lesson quiz.'**
  String get passedQuizNotice;

  /// No description provided for @nextLessonLabel.
  ///
  /// In en, this message translates to:
  /// **'Next lesson: {title}'**
  String nextLessonLabel(String title);

  /// No description provided for @previousLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Previous Lesson'**
  String get previousLessonAction;

  /// No description provided for @nextLessonAction.
  ///
  /// In en, this message translates to:
  /// **'Next Lesson'**
  String get nextLessonAction;

  /// No description provided for @lessonXofY.
  ///
  /// In en, this message translates to:
  /// **'Lesson {current} of {total}'**
  String lessonXofY(int current, int total);

  /// No description provided for @lessonMaterialTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson Material'**
  String get lessonMaterialTitle;

  /// No description provided for @openPdfAction.
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get openPdfAction;

  /// No description provided for @completeVideoToUnlockQuiz.
  ///
  /// In en, this message translates to:
  /// **'Complete the video to unlock the lesson quiz.'**
  String get completeVideoToUnlockQuiz;

  /// No description provided for @videoCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Video completed'**
  String get videoCompletedTitle;

  /// No description provided for @courseAssessmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Assessments'**
  String get courseAssessmentsTitle;

  /// No description provided for @lessonQuizzesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson Quizzes'**
  String get lessonQuizzesSectionTitle;

  /// No description provided for @lessonQuizzesSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed as part of your lesson progression.'**
  String get lessonQuizzesSectionDesc;

  /// No description provided for @generalExamsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'General Exams'**
  String get generalExamsSectionTitle;

  /// No description provided for @generalExamsSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Additional course-wide assessments.'**
  String get generalExamsSectionDesc;

  /// No description provided for @lessonsCompletedRatio.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} lessons completed'**
  String lessonsCompletedRatio(int completed, int total);

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{pct}% Complete'**
  String percentComplete(int pct);

  /// No description provided for @viewLessonsAction.
  ///
  /// In en, this message translates to:
  /// **'View Lessons'**
  String get viewLessonsAction;

  /// No description provided for @courseLessonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Lessons'**
  String get courseLessonsTitle;

  /// No description provided for @addLessonButton.
  ///
  /// In en, this message translates to:
  /// **'Add Lesson'**
  String get addLessonButton;

  /// No description provided for @courseBuilderEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Lessons Yet'**
  String get courseBuilderEmptyTitle;

  /// No description provided for @courseBuilderEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start building your course by adding a lesson.'**
  String get courseBuilderEmptySubtitle;

  /// No description provided for @sequentialLearning.
  ///
  /// In en, this message translates to:
  /// **'Sequential Learning'**
  String get sequentialLearning;

  /// No description provided for @sequentialLearningDesc.
  ///
  /// In en, this message translates to:
  /// **'Students must complete each lesson\'s video and pass the lesson quiz before the next lesson unlocks.'**
  String get sequentialLearningDesc;

  /// Error when no video selected
  ///
  /// In en, this message translates to:
  /// **'Please select a video first.'**
  String get lessonEditorErrorSelectVideo;

  /// Error saving lesson
  ///
  /// In en, this message translates to:
  /// **'An error occurred while saving.'**
  String get lessonEditorErrorSaving;

  /// Edit lesson dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Lesson'**
  String get lessonEditorEditTitle;

  /// Add new lesson dialog title
  ///
  /// In en, this message translates to:
  /// **'Add New Lesson'**
  String get lessonEditorAddTitle;

  /// Source video section title
  ///
  /// In en, this message translates to:
  /// **'Source Video'**
  String get lessonEditorSourceVideo;

  /// Tooltip to change video
  ///
  /// In en, this message translates to:
  /// **'Change Video'**
  String get lessonEditorChangeVideo;

  /// Button to select video from library
  ///
  /// In en, this message translates to:
  /// **'Select from Library'**
  String get lessonEditorSelectFromLibrary;

  /// Button to upload new video
  ///
  /// In en, this message translates to:
  /// **'Upload New'**
  String get lessonEditorUploadNew;

  /// Lesson title field label
  ///
  /// In en, this message translates to:
  /// **'Lesson Title (Optional Override)'**
  String get lessonEditorLessonTitle;

  /// Hint for lesson title field
  ///
  /// In en, this message translates to:
  /// **'Enter lesson title'**
  String get lessonEditorLessonTitleHint;

  /// Study material section title
  ///
  /// In en, this message translates to:
  /// **'Study Material (PDF)'**
  String get lessonEditorStudyMaterial;

  /// Upload PDF button
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get lessonEditorUploadPdf;

  /// Lesson quiz section title
  ///
  /// In en, this message translates to:
  /// **'Lesson Quiz'**
  String get lessonEditorLessonQuiz;

  /// Message when no quizzes are available
  ///
  /// In en, this message translates to:
  /// **'No quizzes available in this group.'**
  String get lessonEditorNoQuizzes;

  /// Dropdown item for no quiz
  ///
  /// In en, this message translates to:
  /// **'No Quiz'**
  String get lessonEditorNoQuiz;

  /// Passing score section title
  ///
  /// In en, this message translates to:
  /// **'Passing Score Requirements'**
  String get lessonEditorPassingScoreReq;

  /// Custom passing score field label
  ///
  /// In en, this message translates to:
  /// **'Custom Passing Score'**
  String get lessonEditorCustomPassingScore;

  /// Message for default passing score
  ///
  /// In en, this message translates to:
  /// **'Using default group passing score ({score}%)'**
  String lessonEditorDefaultPassingScore(int score);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
