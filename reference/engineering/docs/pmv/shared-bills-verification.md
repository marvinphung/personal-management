# Shared bills — 1.1.4+6

- Added Mua chung to all 12 existing expense categories, including Công nợ/Đầu tư. It is an additional marker beside the required debt action.
- Added income category Nhận share bill and 12 corresponding tags displaying exact expense category names. finance_defaults also handles active custom expense categories and refreshes labels.
- Migration 011 adds optional tags.display_name while keeping globally unique normalized names/IDs intact. All tag surfaces use readable labels, including forms, history, filters and catalog.
- 105 Flutter tests passed; static analysis clean; eight isolated SQL suites passed. Widget flows save the correct tag/category links for expense, share-bill income and debt expense.
- Migration 011 applied to cloud via the project's direct IPv6 PostgreSQL endpoint after the pooler was unreachable. Existing financial amounts/dates were verified unchanged.
- Signed 1.1.4+6 built and installed on A54. Verified actual expense selector shows #Mua chung after sync; further screen inspection was interrupted by the user's handoff request. No test transaction was saved. Prior debt-date functionality remains included.
- Local verification images/logs are ignored by Git under artifacts/ because they may contain personal financial data.
