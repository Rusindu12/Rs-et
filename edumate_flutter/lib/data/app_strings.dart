class AppStrings {
  const AppStrings(this.sinhala);

  final bool sinhala;

  String get home => sinhala ? 'මුල් පිටුව' : 'Home';
  String get chat => sinhala ? 'AI කතාබහ' : 'Chat';
  String get library => sinhala ? 'පුස්තකාලය' : 'Library';
  String get quiz => sinhala ? 'ප්‍රශ්න' : 'Quiz';
  String get profile => sinhala ? 'පැතිකඩ' : 'Profile';
  String get subjects => sinhala ? 'විෂයයන්' : 'Subjects';
  String get browse => sinhala ? 'විෂය නිර්දේශය බලන්න' : 'Browse syllabus';
  String get continueLabel => sinhala ? 'ඉදිරියට' : 'Continue';
  String get notes => sinhala ? 'සටහන්' : 'Notes';
  String get video => sinhala ? 'වීඩියෝ' : 'Video';
  String get papers => sinhala ? 'පසුගිය ප්‍රශ්න පත්‍ර' : 'Past papers';
  String get studyStreak => sinhala ? 'අඛණ්ඩ අධ්‍යයන දින' : 'day study streak';
  String get search => sinhala ? 'සොයන්න' : 'Search';
  String get settings => sinhala ? 'සැකසුම්' : 'Settings';

  String sinhahala(String si, String en) => sinhala ? si : en;
}
