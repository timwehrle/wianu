export const year = (date: string) => date.slice(0, 4);
export const issueNumber = (week: string) => week.slice(-2).padStart(3, '0');
