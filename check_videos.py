import os

def check_videos():
    for root, _, files in os.walk('lib/features/videos'):
        for file in files:
            if file.endswith('.dart'):
                p = os.path.join(root, file).replace('\\', '/')
                lines = len(open(p, encoding='utf-8').readlines())
                if lines > 1000:
                    print(f"{p}: {lines} lines")

if __name__ == '__main__':
    check_videos()
