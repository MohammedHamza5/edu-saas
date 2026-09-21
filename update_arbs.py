import json
import sys

def update_arb(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    data.update(new_keys)
    
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

en_keys = {
    'courseBuilderTitle': 'Course Builder',
    'addLessonButton': 'Add Lesson',
    'courseBuilderEmptyTitle': 'No Lessons Yet',
    'courseBuilderEmptySubtitle': 'Start building your course by adding a lesson.'
}

ar_keys = {
    'courseBuilderTitle': 'منشئ المادة',
    'addLessonButton': 'إضافة درس',
    'courseBuilderEmptyTitle': 'لا توجد دروس بعد',
    'courseBuilderEmptySubtitle': 'ابدأ في بناء المادة بإضافة درس.'
}

update_arb('lib/core/localization/arb/app_en.arb', en_keys)
update_arb('lib/core/localization/arb/app_ar.arb', ar_keys)
