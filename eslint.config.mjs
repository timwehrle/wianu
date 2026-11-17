import js from '@eslint/js';
import globals from 'globals';

export default [
	{
		files: ['Wianu/**/*.js'],
		languageOptions: {
			sourceType: 'script',
			globals: globals.browser
		},
		rules: {
			...js.configs.recommended.rules,
			curly: ['error', 'all'],
			'no-empty': ['error', { allowEmptyCatch: true }],
			'no-unused-vars': [
				'error',
				{
					argsIgnorePattern: '^_',
					caughtErrorsIgnorePattern: '^_',
					ignoreRestSiblings: true
				}
			]
		}
	},
	{
		files: ['Wianu/Features/Browser/Scripts/PageInteraction.js'],
		languageOptions: { globals: { blocked: 'readonly' } }
	}
];
