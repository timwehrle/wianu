import adapter from '@sveltejs/adapter-node';
import { sveltekit } from '@sveltejs/kit/vite';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';
import { enhancedImages } from '@sveltejs/enhanced-img';
import { fileURLToPath } from 'node:url';

const breakpointsFile = fileURLToPath(
	new URL('./src/styles/_breakpoints.scss', import.meta.url)
);

const cssPreprocessorOptions = {
	scss: {
		additionalData: `@use "${breakpointsFile}" as *;\n`
	}
};

export default defineConfig({
	css: {
		preprocessorOptions: cssPreprocessorOptions
	},
	plugins: [
		enhancedImages(),
		sveltekit({
			preprocess: vitePreprocess({
				style: { css: { preprocessorOptions: cssPreprocessorOptions } }
			}),
			compilerOptions: {
				runes: ({ filename }) =>
					filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},
			adapter: adapter()
		})
	]
});
