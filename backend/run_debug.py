import asyncio, os
os.environ["RATE_LIMIT_ENABLED"] = "false"
asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
import logging
fh = logging.FileHandler('app_debug.log', mode='w', encoding='utf-8')
fh.setLevel(logging.DEBUG)
fh.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(name)s: %(message)s'))
logging.root.addHandler(fh)
logging.root.setLevel(logging.DEBUG)
import uvicorn
uvicorn.run('app.main:app', host='127.0.0.1', port=8055, log_level='info')
