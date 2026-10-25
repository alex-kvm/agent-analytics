# Analytics Engineering Take Home Exercise

This exercise is about how you model data in dbt and how you reason about data you haven't seen before. Use any tools you like, AI coding agents included. We care more about your decisions, your reasoning, and ability to speak about the decisions you made during the task. The take home task is serving as a conversation starter.

For most candidates it will take 2–4 hours to complete this depending on their familiarity with the tools and data. Afterwards you'll walk a member of the data team through your work in a 1 hour live session over Zoom.

Thanks in advance for your time!

## Context

You just joined the data team at a company that makes a developer platform for building AI agents.

- Customers sign up and create organizations. An organization can have one or more workspaces and a user can be a member of several workspaces
- The app tracks product events via Segment: e.g. page views, track calls and identify calls
- Usage is measured by tracking runs. Runs belong to traces and traces can belong to threads
- The app runs in three regions. Each region has its own database and its own event stream

## Data

The repo contains synthetic raw data and a dbt project that runs locally on DuckDB. The sources are set up, but nobody has built any models yet. The setup steps are in the README.

- App tables per region: organizations, workspaces, users, workspace_memberships
- Events per region: pages, tracks, identifies. Each event has event_id, user_id, anonymous_id, received_at and timestamp, and page events have the page url and path
- Usage: runs with run_id, trace_id, thread_id, workspace_id and timestamps
- A hand-maintained list of internal organizations

The SQL dialect is DuckDB. You don't need to know any specific cloud warehouse.

## Tasks

### 1. Build a data model

The product team sent the note below. Build a dbt model that answers it

> Hi! We're planning next quarter and want to know which of our customers actively use the platform, and which parts of the product they use. Right now every question turns into a one-off query, and the answers don't always agree with each other. We'd love something we can keep coming back to.
>
> We don't have a definition of an active customer yet. Help us define what an active user and an active organization mean for us.
>
> We're not sure this is the right question, so push back if it isn't. Share with us what you assumed and the questions you'd like to ask the product team.

Follow a data modeling strategy and be able to explain the benefits of modeling data in the way you choose

### 2. Write down what you found

If you find things in the data that you don't trust, write them down in an `ISSUES.md` file ranked by impact. For each one, add a line on why it matters and the query that shows it. Fix the ones that would make your answers wrong and note for each issue whether you fixed it or left it and why.

### 3. Tell us what you'd do next

What answers did you find? What questions does this raise for you? Where would you take the model next, which analyses would you want to run, and what would you suggest to the business?

## What to send us

Push the project to your own private GitHub repo and share it with the GitHub account we send you by email before the interview. A pull request inside your repo is a good way to show your changes. It should include:

- your dbt project
- ISSUES.md
- a short write-up covering your model structure and why you chose it, your answer to the product team with the SQL you used, your assumptions, the questions you'd ask the product team, and your answers to task 3

## Glossary

- Organization: a customer account. It holds one or more workspaces
- Workspace: where a team works. Usage and most product activity belong to a workspace
- User and Member: a person with a login. Members belong to one or more workspaces
- Run, trace, thread: a run is one step an agent takes. A trace groups the runs of one request. A thread groups traces from one conversation
- Playground: a page where users try prompts and models by hand
- Experiments: pages where users compare the outputs of different versions of their agent
- Region: one of three separate deployments of the app
