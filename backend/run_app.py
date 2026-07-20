import asyncio, os
os.environ["RATE_LIMIT_ENABLED"] = "false"
asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
import uvicorn
uvicorn.run('app.main:app', host='127.0.0.1', port=8099, log_level='info')
