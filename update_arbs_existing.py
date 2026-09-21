import json
import sys

def update_arb(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    data.update(new_keys)
    
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

en_keys = {
    'groupDetailTitle': 'Course Details',
    'groupNotFound': 'Course not found',
    'backToGroups': 'Back to Courses',
    'groupServicesAndTools': 'Course Tools',
    'groupMembersCountHeader': 'Enrolled Students ({count})'
}

ar_keys = {
    'groupDetailTitle': 'تفاصيل المادة',
    'groupNotFound': 'لم يتم العثور على المادة',
    'backToGroups': 'العودة للمواد',
    'groupServicesAndTools': 'أدوات المادة',
    'groupMembersCountHeader': 'الطلاب المسجلين ({count})'
}

update_arb('lib/core/localization/arb/app_en.arb', en_keys)
update_arb('lib/core/localization/arb/app_ar.arb', ar_keys)
