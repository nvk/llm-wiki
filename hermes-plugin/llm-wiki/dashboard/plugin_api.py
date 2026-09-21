"""Profile-scoped backend routes for the llm-wiki desktop pane."""

from fastapi import APIRouter, HTTPException

from llm_wiki_tools import inspect_wiki

router = APIRouter()


@router.get("/status")
async def status(path: str):
    report = inspect_wiki(path)
    if not report["exists"]:
        raise HTTPException(status_code=404, detail=report)
    return report
