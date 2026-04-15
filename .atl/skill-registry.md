# Skill Registry

**Delegator use only.** Any agent that launches sub-agents reads this registry to resolve compact rules, then injects them directly into sub-agent prompts. Sub-agents do NOT read this registry or individual SKILL.md files.

See `_shared/skill-resolver.md` for the full resolution protocol.

## User Skills

| Trigger | Skill | Path |
|---------|-------|------|
| Creating a GitHub issue, reporting a bug, or requesting a feature | issue-creation | ~/.config/opencode/skills/issue-creation/SKILL.md |
| Creating a pull request, opening a PR, or preparing changes for review | branch-pr | ~/.config/opencode/skills/branch-pr/SKILL.md |
| "judgment day", "judgment-day", "review adversarial", "dual review", "doble review", "juzgar", "que lo juzguen" | judgment-day | ~/.config/opencode/skills/judgment-day/SKILL.md |
| Review PRs, analyze issues, or audit PR/issue backlog. "pr review", "revisar pr", "qué PRs hay", "PRs pendientes", "issues abiertos", "sin atención", "hacer review" | pr-review | ~/.config/opencode/skills/pr-review/SKILL.md |
| Reviewing technical exercises, code assessments, candidate submissions, or take-home tests | technical-review | ~/.config/opencode/skills/technical-review/SKILL.md |
| Create a new skill, add agent instructions, or document patterns for AI | skill-creator | ~/.config/opencode/skills/skill-creator/SKILL.md |
| Building a presentation, slide deck, course material, stream web, or talk slides | stream-deck | ~/.config/opencode/skills/stream-deck/SKILL.md |
| Release, bump version, update homebrew, or publish a new version | homebrew-release | ~/.config/opencode/skills/homebrew-release/SKILL.md |
| Create an epic, large feature, or multi-task initiative | jira-epic | ~/.config/opencode/skills/jira-epic/SKILL.md |
| Create a Jira task, ticket, or issue | jira-task | ~/.config/opencode/skills/jira-task/SKILL.md |

## Compact Rules

Pre-digested rules per skill. Delegators copy matching blocks into sub-agent prompts as `## Project Standards (auto-resolved)`.

### issue-creation
- Blank issues are disabled — MUST use a template (bug report or feature request)
- Every issue gets `status:needs-review` automatically on creation
- A maintainer MUST add `status:approved` before any PR can be opened
- Questions go to Discussions, not issues
- Follow the issue-first enforcement system: issue → approval → PR

### branch-pr
- Follow the issue-first enforcement system — no PR without approved issue
- PRs MUST reference an approved issue with `status:approved`
- Use conventional commits for PR titles
- All changes MUST pass CI before merge
- Follow the branch naming convention: `<type>/<issue-number>-<short-description>`

### judgment-day
- Launches two independent blind judge sub-agents simultaneously
- Each judge reviews the same target independently
- Synthesizes findings from both judges
- Applies fixes and re-judges until both pass
- Escalates after 2 iterations if still failing
- Triggers: "judgment day", "judgment-day", "review adversarial", "dual review", "doble review", "juzgar", "que lo juzguen"

### pr-review
- Review GitHub PRs and Issues with structured analysis
- Check for: issue linkage, conventional commits, test coverage, code quality
- Analyze issues for: bug reports, feature requests, triage needs
- Key phrases: "pr review", "revisar pr", "qué PRs hay", "PRs pendientes", "issues abiertos", "sin atención", "hacer review"
- Provide structured feedback: summary, issues found, recommendations

### technical-review
- Review technical exercises and candidate submissions with structured evaluation
- Evaluate against: correctness, code quality, architecture, testing, best practices
- Provide scored assessment with specific feedback
- Identify strengths and areas for improvement

### skill-creator
- Creates new AI agent skills following the Agent Skills spec
- Skills MUST have: name, description with trigger, SKILL.md file
- Follow the skill file format: frontmatter + sections
- Place skills in the appropriate skills directory

### stream-deck
- Create slide-deck presentation webs using Gentleman Kanagawa Blur theme
- Use inline SVG diagrams for visual content
- Support for streams and courses
- Follow the presentation structure: title, sections, code examples

### homebrew-release
- Release workflow for Gentleman-Programming homebrew-tap projects
- Bump version in project, update homebrew formula, publish new version
- Follow semantic versioning
- Update SHA256 checksums for new releases

### jira-epic
- Creates Jira epics for large features following Prowler's standard format
- Include: epic name, description, acceptance criteria, linked issues
- Follow the epic template structure

### jira-task
- Creates Jira tasks following Prowler's standard format
- Include: task name, description, acceptance criteria, estimates
- Follow the task template structure

## Project Conventions

| File | Path | Notes |
|------|------|-------|
| CLAUDE.md | /home/maicol/Documents/caicedo-seguros/conecta-seguros-backend/CLAUDE.md | Main project conventions — hexagonal architecture, DDD, Spring Boot patterns |

Read the convention files listed above for project-specific patterns and rules. All referenced paths have been extracted — no need to read index files to discover more.
