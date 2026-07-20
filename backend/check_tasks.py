import sys
sys.path.insert(0, r"C:\Users\1`030 G4\OneDrive\Desktop\sir A.K hee\Dot Agni\APEX_Housing\backend")

from app.tasks.celery_app import celery_app

# Force task registration
celery_app.loader.import_default_modules()

tasks = [name for name in sorted(celery_app.tasks.keys()) if not name.startswith("celery.")]
print(f"Registered tasks: {len(tasks)}")
for t in tasks:
    print(f"  - {t}")

print()
print("Beat schedule:")
for name, conf in celery_app.conf.beat_schedule.items():
    task = conf["task"]
    sched = conf["schedule"]
    print(f"  {name}: {task} every {sched}s")
