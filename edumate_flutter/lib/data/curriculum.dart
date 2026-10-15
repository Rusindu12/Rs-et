import 'package:flutter/material.dart';

import '../models/study_models.dart';

const primarySubjects = <Subject>[
  Subject(id: 'sinhala', nameEn: 'Sinhala', nameSi: 'සිංහල', icon: Icons.menu_book_rounded, colorValue: 0xff6C63FF),
  Subject(id: 'mathematics', nameEn: 'Mathematics', nameSi: 'ගණිතය', icon: Icons.calculate_rounded, colorValue: 0xffFF8A65),
  Subject(id: 'english', nameEn: 'English', nameSi: 'ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xff42A5F5),
  Subject(id: 'environment', nameEn: 'Environment', nameSi: 'පරිසරය', icon: Icons.public_rounded, colorValue: 0xff66BB6A),
  Subject(id: 'religion', nameEn: 'Religion', nameSi: 'ආගම', icon: Icons.self_improvement_rounded, colorValue: 0xffAB72D1),
  Subject(id: 'tamil', nameEn: 'Tamil', nameSi: 'දෙමළ', icon: Icons.language_rounded, colorValue: 0xffF2B84B),
];

const juniorSubjects = <Subject>[
  Subject(id: 'sinhala', nameEn: 'Sinhala', nameSi: 'සිංහල', icon: Icons.menu_book_rounded, colorValue: 0xff6C63FF),
  Subject(id: 'english', nameEn: 'English', nameSi: 'ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xff42A5F5),
  Subject(id: 'mathematics', nameEn: 'Mathematics', nameSi: 'ගණිතය', icon: Icons.calculate_rounded, colorValue: 0xffFF8A65),
  Subject(id: 'science', nameEn: 'Science', nameSi: 'විද්‍යාව', icon: Icons.science_rounded, colorValue: 0xff26A69A),
  Subject(id: 'history', nameEn: 'History', nameSi: 'ඉතිහාසය', icon: Icons.account_balance_rounded, colorValue: 0xffE8A83E),
  Subject(id: 'buddhism', nameEn: 'Buddhism', nameSi: 'බුද්ධ ධර්මය', icon: Icons.spa_rounded, colorValue: 0xffB786D6),
  Subject(id: 'geography', nameEn: 'Geography', nameSi: 'භූගෝල විද්‍යාව', icon: Icons.explore_rounded, colorValue: 0xff4CAF80),
  Subject(id: 'ict', nameEn: 'ICT', nameSi: 'තොරතුරු තාක්ෂණය', icon: Icons.computer_rounded, colorValue: 0xff6478E8),
];

const olSubjects = <Subject>[
  Subject(id: 'sinhala', nameEn: 'Sinhala', nameSi: 'සිංහල', icon: Icons.menu_book_rounded, colorValue: 0xff6C63FF),
  Subject(id: 'english', nameEn: 'English', nameSi: 'ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xff42A5F5),
  Subject(id: 'mathematics', nameEn: 'Mathematics', nameSi: 'ගණිතය', icon: Icons.calculate_rounded, colorValue: 0xffFF8A65),
  Subject(id: 'science', nameEn: 'Science', nameSi: 'විද්‍යාව', icon: Icons.science_rounded, colorValue: 0xff26A69A),
  Subject(id: 'history', nameEn: 'History', nameSi: 'ඉතිහාසය', icon: Icons.account_balance_rounded, colorValue: 0xffE8A83E),
  Subject(id: 'buddhism', nameEn: 'Buddhism', nameSi: 'බුද්ධ ධර්මය', icon: Icons.spa_rounded, colorValue: 0xffB786D6),
  Subject(id: 'ict', nameEn: 'ICT', nameSi: 'තොරතුරු තාක්ෂණය', icon: Icons.computer_rounded, colorValue: 0xff6478E8),
  Subject(id: 'business', nameEn: 'Business & Accounting', nameSi: 'ව්‍යාපාර හා ගිණුම්කරණය', icon: Icons.trending_up_rounded, colorValue: 0xffEF6C83),
];

const physicalScience = <Subject>[
  Subject(id: 'combined-maths', nameEn: 'Combined Mathematics', nameSi: 'සංයුක්ත ගණිතය', icon: Icons.functions_rounded, colorValue: 0xff6C63FF),
  Subject(id: 'physics', nameEn: 'Physics', nameSi: 'භෞතික විද්‍යාව', icon: Icons.bolt_rounded, colorValue: 0xff42A5F5),
  Subject(id: 'chemistry', nameEn: 'Chemistry', nameSi: 'රසායන විද්‍යාව', icon: Icons.science_rounded, colorValue: 0xff26A69A),
  Subject(id: 'general-english', nameEn: 'General English', nameSi: 'සාමාන්‍ය ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xffF2B84B),
];
const biologicalScience = <Subject>[
  Subject(id: 'biology', nameEn: 'Biology', nameSi: 'ජීව විද්‍යාව', icon: Icons.biotech_rounded, colorValue: 0xff4CAF80),
  Subject(id: 'chemistry', nameEn: 'Chemistry', nameSi: 'රසායන විද්‍යාව', icon: Icons.science_rounded, colorValue: 0xff26A69A),
  Subject(id: 'physics', nameEn: 'Physics', nameSi: 'භෞතික විද්‍යාව', icon: Icons.bolt_rounded, colorValue: 0xff42A5F5),
  Subject(id: 'general-english', nameEn: 'General English', nameSi: 'සාමාන්‍ය ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xffF2B84B),
];
const commerce = <Subject>[
  Subject(id: 'accounting', nameEn: 'Accounting', nameSi: 'ගිණුම්කරණය', icon: Icons.calculate_rounded, colorValue: 0xff6C63FF),
  Subject(id: 'business-studies', nameEn: 'Business Studies', nameSi: 'ව්‍යාපාර අධ්‍යයනය', icon: Icons.storefront_rounded, colorValue: 0xffFF8A65),
  Subject(id: 'economics', nameEn: 'Economics', nameSi: 'ආර්ථික විද්‍යාව', icon: Icons.show_chart_rounded, colorValue: 0xff26A69A),
  Subject(id: 'general-english', nameEn: 'General English', nameSi: 'සාමාන්‍ය ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xffF2B84B),
];
const arts = <Subject>[
  Subject(id: 'political-science', nameEn: 'Political Science', nameSi: 'දේශපාලන විද්‍යාව', icon: Icons.account_balance_rounded, colorValue: 0xff6C63FF),
  Subject(id: 'logic', nameEn: 'Logic', nameSi: 'තර්ක ශාස්ත්‍රය', icon: Icons.psychology_rounded, colorValue: 0xff42A5F5),
  Subject(id: 'geography', nameEn: 'Geography', nameSi: 'භූගෝල විද්‍යාව', icon: Icons.explore_rounded, colorValue: 0xff4CAF80),
  Subject(id: 'general-english', nameEn: 'General English', nameSi: 'සාමාන්‍ය ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xffF2B84B),
];
const technology = <Subject>[
  Subject(id: 'engineering-technology', nameEn: 'Engineering Technology', nameSi: 'ඉංජිනේරු තාක්ෂණවේදය', icon: Icons.precision_manufacturing_rounded, colorValue: 0xff6C63FF),
  Subject(id: 'science-technology', nameEn: 'Science for Technology', nameSi: 'තාක්ෂණවේදය සඳහා විද්‍යාව', icon: Icons.science_rounded, colorValue: 0xff26A69A),
  Subject(id: 'ict', nameEn: 'ICT', nameSi: 'තොරතුරු තාක්ෂණය', icon: Icons.computer_rounded, colorValue: 0xff6478E8),
  Subject(id: 'general-english', nameEn: 'General English', nameSi: 'සාමාන්‍ය ඉංග්‍රීසි', icon: Icons.translate_rounded, colorValue: 0xffF2B84B),
];

const streamOptions = <StreamOption>[
  StreamOption(id: 'physical-science', nameEn: 'Physical Science', nameSi: 'භෞතික විද්‍යා', icon: '⚛️', colorValue: 0xff6871E8),
  StreamOption(id: 'biological-science', nameEn: 'Biological Science', nameSi: 'ජීව විද්‍යා', icon: '🧬', colorValue: 0xff39A982),
  StreamOption(id: 'commerce', nameEn: 'Commerce', nameSi: 'වාණිජ', icon: '📊', colorValue: 0xffF0A94E),
  StreamOption(id: 'arts', nameEn: 'Arts', nameSi: 'කලා', icon: '🎨', colorValue: 0xffE77C91),
  StreamOption(id: 'technology', nameEn: 'Technology', nameSi: 'තාක්ෂණවේදය', icon: '⚙️', colorValue: 0xff44A7C7),
];

List<Subject> subjectsForGrade(int grade, {String? streamId}) {
  if (grade >= 12) {
    switch (streamId) {
      case 'physical-science':
        return physicalScience;
      case 'biological-science':
        return biologicalScience;
      case 'commerce':
        return commerce;
      case 'arts':
        return arts;
      case 'technology':
        return technology;
      default:
        return const [];
    }
  }
  if (grade >= 10) return olSubjects;
  if (grade >= 6) return juniorSubjects;
  return primarySubjects;
}

String stageForGrade(int grade, {bool sinhala = false}) {
  if (grade <= 5) return sinhala ? 'ප්‍රාථමික' : 'Primary';
  if (grade <= 9) return sinhala ? 'කනිෂ්ඨ ද්විතීයික' : 'Junior secondary';
  if (grade <= 11) return sinhala ? 'සාමාන්‍ය පෙළ' : 'O/L';
  return sinhala ? 'උසස් පෙළ' : 'A/L';
}

String streamName(String? id, {bool sinhala = false}) {
  if (id == null) return '';
  for (final stream in streamOptions) {
    if (stream.id == id) return stream.title(sinhala);
  }
  return id;
}

List<Chapter> chaptersFor(Subject subject) {
  final labels = switch (subject.id) {
    'mathematics' => <(String, String)>[
        ('Numbers and operations', 'සංඛ්‍යා හා ගණිත ක්‍රියා'),
        ('Algebraic expressions', 'වීජීය ප්‍රකාශන'),
        ('Equations and graphs', 'සමීකරණ හා ප්‍රස්තාර'),
        ('Geometry', 'ජ්‍යාමිතිය'),
        ('Statistics and probability', 'සංඛ්‍යාන හා සම්භාවිතාව'),
      ],
    'science' || 'physics' || 'chemistry' || 'biology' => <(String, String)>[
        ('Living things and systems', 'ජීවීන් හා පද්ධති'),
        ('Matter and its properties', 'පදාර්ථය හා එහි ගුණ'),
        ('Energy and forces', 'ශක්තිය හා බල'),
        ('The environment', 'පරිසරය'),
        ('Revision and applications', 'පුනරීක්ෂණය හා යෙදවීම්'),
      ],
    'english' || 'general-english' => <(String, String)>[
        ('Reading for meaning', 'අර්ථය සඳහා කියවීම'),
        ('Grammar in context', 'සන්දර්භයේ ව්‍යාකරණ'),
        ('Writing skills', 'ලිවීමේ කුසලතා'),
        ('Speaking and listening', 'කථනය හා සවන්දීම'),
      ],
    'history' => <(String, String)>[
        ('Sources and evidence', 'මූලාශ්‍ර හා සාක්ෂි'),
        ('Ancient Sri Lanka', 'පුරාණ ශ්‍රී ලංකාව'),
        ('Kingdoms and society', 'රාජධානි හා සමාජය'),
        ('Modern Sri Lanka', 'නූතන ශ්‍රී ලංකාව'),
      ],
    _ => <(String, String)>[
        ('Key ideas and vocabulary', 'ප්‍රධාන සංකල්ප හා වචන'),
        ('Core concepts', 'මූලික සංකල්ප'),
        ('Practice and examples', 'අභ්‍යාස හා උදාහරණ'),
        ('Review and apply', 'පුනරීක්ෂණය හා යෙදවීම'),
      ],
  };
  return List.generate(labels.length, (index) {
    final (en, si) = labels[index];
    final progress = index == 0 ? 0.72 : (index == 1 ? 0.35 : 0.0);
    return Chapter(
      id: 'chapter-${index + 1}',
      titleEn: 'Chapter ${index + 1}: $en',
      titleSi: 'පාඩම ${index + 1}: $si',
      summaryEn: 'A guided lesson with key ideas, worked examples and a quick review.',
      summarySi: 'ප්‍රධාන අදහස්, විසඳූ උදාහරණ සහ කෙටි පුනරීක්ෂණයක් සහිත පාඩමකි.',
      progress: progress,
      notes: [
        'Start with the key idea and connect it to a familiar real-life example.',
        'Work through one example slowly, showing each step and checking the units or notation.',
        'Try the practice question without looking at the answer, then explain why the method works.',
      ],
    );
  });
}

const sampleQuiz = <QuizQuestion>[
  QuizQuestion(
    question: 'What is the value of 2³?',
    options: ['6', '8', '9', '12'],
    correctIndex: 1,
    explanation: '2³ means 2 × 2 × 2, which equals 8.',
  ),
  QuizQuestion(
    question: 'Solve: 3x = 12',
    options: ['x = 3', 'x = 4', 'x = 9', 'x = 15'],
    correctIndex: 1,
    explanation: 'Divide both sides by 3: x = 12 ÷ 3 = 4.',
  ),
  QuizQuestion(
    question: 'A rectangle is 5 cm long and 3 cm wide. What is its area?',
    options: ['8 cm²', '15 cm²', '16 cm²', '30 cm²'],
    correctIndex: 1,
    explanation: 'Area = length × width = 5 × 3 = 15 cm².',
  ),
  QuizQuestion(
    question: 'Which fraction is equal to 0.25?',
    options: ['1/2', '1/3', '1/4', '3/4'],
    correctIndex: 2,
    explanation: '0.25 = 25/100. Simplifying by 25 gives 1/4.',
  ),
  QuizQuestion(
    question: 'If x + 5 = 12, what is x?',
    options: ['5', '7', '12', '17'],
    correctIndex: 1,
    explanation: 'Subtract 5 from both sides: x = 12 − 5 = 7.',
  ),
];

const _scienceQuiz = <QuizQuestion>[
  QuizQuestion(question: 'Which gas do green plants use during photosynthesis?', options: ['Oxygen', 'Carbon dioxide', 'Nitrogen', 'Hydrogen'], correctIndex: 1, explanation: 'Plants use carbon dioxide and water, with light energy, to make glucose during photosynthesis.'),
  QuizQuestion(question: 'What is the SI unit of force?', options: ['Joule', 'Watt', 'Newton', 'Pascal'], correctIndex: 2, explanation: 'Force is measured in newtons (N), named after scientist Isaac Newton.'),
  QuizQuestion(question: 'At ordinary room temperature, water is usually a…', options: ['Solid', 'Liquid', 'Gas', 'Plasma'], correctIndex: 1, explanation: 'At typical room temperature and atmospheric pressure, water is a liquid.'),
  QuizQuestion(question: 'Which of these is a renewable energy source?', options: ['Coal', 'Petroleum', 'Solar energy', 'Natural gas'], correctIndex: 2, explanation: 'Sunlight is naturally replenished and is considered a renewable energy source.'),
  QuizQuestion(question: 'Which part of a plant mainly absorbs water from the soil?', options: ['Flower', 'Leaf', 'Root', 'Fruit'], correctIndex: 2, explanation: 'Roots, especially their root hairs, absorb water and minerals from the soil.'),
];

const _englishQuiz = <QuizQuestion>[
  QuizQuestion(question: 'Choose the correct sentence.', options: ['She go to school.', 'She goes to school.', 'She going to school.', 'She gone to school.'], correctIndex: 1, explanation: 'In the simple present tense, use “goes” with the third-person singular subject “she”.'),
  QuizQuestion(question: 'What is the plural of “child”?', options: ['Childs', 'Childes', 'Children', 'Childrens'], correctIndex: 2, explanation: '“Children” is the irregular plural form of “child”.'),
  QuizQuestion(question: 'Choose the opposite of “careful”.', options: ['Cautious', 'Careless', 'Gentle', 'Patient'], correctIndex: 1, explanation: '“Careless” means not taking care, so it is an antonym of “careful”.'),
  QuizQuestion(question: 'Which word is an adjective in “a bright star”?', options: ['a', 'bright', 'star', 'none'], correctIndex: 1, explanation: '“Bright” describes the noun “star”, so it is an adjective.'),
  QuizQuestion(question: 'Choose the correct past tense: “They ___ the match yesterday.”', options: ['win', 'wins', 'won', 'winning'], correctIndex: 2, explanation: '“Yesterday” indicates the past; the past tense of “win” is “won”.'),
];

const _historyQuiz = <QuizQuestion>[
  QuizQuestion(question: 'Which ancient Sri Lankan kingdom is associated with the city of Anuradhapura?', options: ['Anuradhapura Kingdom', 'Kotte Kingdom', 'Jaffna Kingdom', 'Sitawaka Kingdom'], correctIndex: 0, explanation: 'Anuradhapura served as a major ancient capital and the centre of the Anuradhapura Kingdom.'),
  QuizQuestion(question: 'Why do historians study primary sources?', options: ['They are always perfect', 'They provide evidence from the period studied', 'They replace all research', 'They are modern summaries'], correctIndex: 1, explanation: 'Primary sources were created in or near the time being studied and can provide direct evidence.'),
  QuizQuestion(question: 'Which is an example of a historical source?', options: ['An inscription', 'A weather forecast', 'A calculator', 'A traffic light'], correctIndex: 0, explanation: 'Inscriptions are material records that historians can examine as evidence.'),
  QuizQuestion(question: 'A timeline is mainly used to show…', options: ['The order of events', 'The size of a country', 'The spelling of words', 'The weather'], correctIndex: 0, explanation: 'A timeline arranges events in chronological order.'),
  QuizQuestion(question: 'What should a historian do when sources disagree?', options: ['Ignore all sources', 'Compare evidence and context', 'Choose the longest source', 'Guess'], correctIndex: 1, explanation: 'Historians compare sources, authorship, context and evidence before drawing conclusions.'),
];

List<QuizQuestion> quizForSubject(String? subjectId) {
  switch (subjectId) {
    case 'science':
    case 'physics':
    case 'chemistry':
    case 'biology':
      return _scienceQuiz;
    case 'english':
    case 'general-english':
      return _englishQuiz;
    case 'history':
      return _historyQuiz;
    default:
      return sampleQuiz;
  }
}
