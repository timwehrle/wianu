import js from '@eslint/js';
import stylistic from '@stylistic/eslint-plugin';
import globals from 'globals';

export default [
	{
		files: ['Wianu/**/*.js'],
		plugins: { '@stylistic': stylistic },
		languageOptions: {
			sourceType: 'script',
			globals: globals.browser
		},
		rules: {
			...js.configs.recommended.rules,
			curly: ['error', 'all'],
			'@stylistic/padding-line-between-statements': [
				'error',
				{ blankLine: 'always', prev: '*', next: 'multiline-block-like' },
				{ blankLine: 'always', prev: 'multiline-block-like', next: '*' },
				{
					blankLine: 'always',
					prev: {
						selector:
							'IfStatement:has(> :matches(ReturnStatement, ThrowStatement))'
					},
					next: '*'
				},
				{ blankLine: 'always', prev: ['const', 'let', 'var'], next: '*' },
				{
					blankLine: 'any',
					prev: ['const', 'let', 'var'],
					next: ['const', 'let', 'var']
				},
				{ blankLine: 'always', prev: '*', next: 'return' },
				{ blankLine: 'always', prev: 'function', next: '*' }
			],
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
