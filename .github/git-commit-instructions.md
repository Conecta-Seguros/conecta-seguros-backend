# Instructions for generating commit messages with Copilot

1. Always use an imperative verb at the beginning of your message. Examples: Add, Fix, Change, Remove, Update, Refactor.

2. Do not use periods or ellipses in your message.

3. The main message (title) should be a maximum of 50 characters. Be clear and concise.

4. If you need to add context or explanation, use a message body separated by a blank line after the title. You can use
   regular punctuation in the body.

5. Use semantic prefixes for the commit type, following this convention:

    - feat: for new features
    - fix: for bug fixes
    - perf: for performance improvements
    - build: for changes to the build or deployment system
    - ci: for changes to continuous integration
    - docs: for documentation changes
    - refactor: for code refactoring without functional changes
    - style: for formatting changes, spaces, tabs, without affecting functionality
    - test: to add or modify tests

6. If the commit affects a specific area or module, use the scope in parentheses after the type, for example: feat(
   backend): add new API endpoint

7. The message should complete the sentence: "If I apply this commit, then this commit..."

Correct example:

feat(auth): add login with Google

Add support for Google OAuth login to improve user authentication options.

---

Remember that the message must be a clear and direct instruction about the change being made.