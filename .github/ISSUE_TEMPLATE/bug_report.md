---
name: Bug report
about: Create a report to help make this better
title: "[BUG]"
labels: bug
assignees: otherguy

---

**Describe the bug**
A clear and concise description of what the bug is.

**Versions:**
 - Docker (`docker --version`): 
 - Docker Compose (_if used_) (`docker-compose --version`):
 - Image Name: (`docker inspect --format='{{.Config.Image}}' [container name]`) 
 - Image ID: (`docker inspect --format='{{.Image}}' [container name]`)
 - Labels: (`docker inspect --format='{{json .Config.Labels}}' [container name]`)

**Run Command:**
How did you start the container? If you use `docker-compose`, also add your compose file here.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Additional context**
Add any other context about the problem here.
