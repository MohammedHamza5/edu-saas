import json
import sys

def update_arb(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    data.update(new_keys)
    
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

en_keys = {
    'confirmRemoveMemberTitle': 'Remove Student',
    'confirmRemoveMemberBody': 'Are you sure you want to remove student "{name}" from this course?'
}

ar_keys = {
    'confirmRemoveMemberTitle': 'حذف طالب',
    'confirmRemoveMemberBody': 'هل أنت متأكد أنك تريد حذف الطالب "{name}" من هذه المادة؟'
}

update_arb('lib/core/localization/arb/app_en.arb', en_keys)
update_arb('lib/core/localization/arb/app_ar.arb', ar_keys)
