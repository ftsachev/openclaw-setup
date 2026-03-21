@echo off
REM update-agents.cmd - Update OpenClaw agent team with latest model config

set "WORKSPACE=%USERPROFILE%\.openclaw\workspace"

echo ============================================
echo OpenClaw Agent Team Update
echo ============================================
echo.

REM Copy AGENT_MODELS.md to workspace
echo Copying AGENT_MODELS.md to workspace...
copy /Y "%~dp0AGENT_MODELS.md" "%WORKSPACE%\AGENT_MODELS.md"
echo.

REM Create specialist agent directories
echo Creating agent workspace directories...
if not exist "%WORKSPACE%\assistant" mkdir "%WORKSPACE%\assistant"
if not exist "%WORKSPACE%\backend" mkdir "%WORKSPACE%\backend"
if not exist "%WORKSPACE%\devops" mkdir "%WORKSPACE%\devops"
if not exist "%WORKSPACE%\devsecops" mkdir "%WORKSPACE%\devsecops"
if not exist "%WORKSPACE%\qa-review" mkdir "%WORKSPACE%\qa-review"
echo Done.
echo.

REM Update default model for new agents
echo Updating default model to qwen-portal/coder-model...
openclaw config set "agents.defaults.model.primary" "qwen-portal/coder-model"
echo.

REM Add new specialist agents
echo Adding specialist agents...
openclaw agents add assistant --workspace "%WORKSPACE%\assistant" --model "qwen-portal/coder-model" --non-interactive
openclaw agents add backend --workspace "%WORKSPACE%\backend" --model "qwen-portal/coder-model" --non-interactive
openclaw agents add devops --workspace "%WORKSPACE%\devops" --model "qwen-portal/coder-model" --non-interactive
openclaw agents add devsecops --workspace "%WORKSPACE%\devsecops" --model "qwen-portal/coder-model" --non-interactive
openclaw agents add qa-review --workspace "%WORKSPACE%\qa-review" --model "qwen-portal/coder-model" --non-interactive
echo.

REM Set agent identities
echo Setting agent identities...
openclaw agents set-identity --agent claudia --name "Claudia" --emoji "🧭" --theme "AI orchestrator and team lead"
openclaw agents set-identity --agent assistant --name "Assistant" --emoji "📋" --theme "ops support and coordination"
openclaw agents set-identity --agent backend --name "Backend" --emoji "🛠️" --theme "backend services and integrations"
openclaw agents set-identity --agent frontend --name "Frontend" --emoji "🖥️" --theme "frontend implementation and ux"
openclaw agents set-identity --agent devops --name "DevOps" --emoji "🚦" --theme "deploys infra ci and runtime ops"
openclaw agents set-identity --agent devsecops --name "DevSecOps" --emoji "🔐" --theme "security review and auth secrets"
openclaw agents set-identity --agent qa-review --name "QA Review" --emoji "🧪" --theme "testing regression and release review"
echo.

REM Warm-up agents to force auth-profile inheritance
echo Warming up agents...
openclaw agent --local --agent assistant --message "Say only: assistant ready."
openclaw agent --local --agent backend --message "Say only: backend ready."
openclaw agent --local --agent frontend --message "Say only: frontend ready."
openclaw agent --local --agent devops --message "Say only: devops ready."
openclaw agent --local --agent devsecops --message "Say only: devsecops ready."
openclaw agent --local --agent qa-review --message "Say only: qa-review ready."
echo.

echo ============================================
echo Agent team update complete!
echo ============================================
echo.
echo Next steps:
echo   openclaw agents list
echo   openclaw status
echo.
