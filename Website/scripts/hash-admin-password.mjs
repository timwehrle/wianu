import { randomBytes, scrypt as scryptCallback } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback);

async function readPassword() {
	if (!process.stdin.isTTY) {
		let input = '';
		for await (const chunk of process.stdin) {
			input += chunk;
		}
		return input.replace(/\r?\n$/, '');
	}
	process.stderr.write('Admin password: ');
	process.stdin.setRawMode(true);
	process.stdin.resume();
	let password = '';
	try {
		for await (const chunk of process.stdin) {
			for (const character of String(chunk)) {
				if (character === '\r' || character === '\n') {
					process.stderr.write('\n');
					return password;
				}
				if (character === '\u0003') {
					process.exit(130);
				}
				if (character === '\u007f') {
					password = password.slice(0, -1);
				} else {
					password += character;
				}
			}
		}
		return password;
	} finally {
		process.stdin.setRawMode(false);
		process.stdin.pause();
	}
}

const password = await readPassword();
if (!password) {
	process.stderr.write('Password cannot be empty.\n');
	process.exitCode = 1;
} else {
	const salt = randomBytes(16);
	const hash = (await scrypt(password, salt, 32)).toString('base64url');
	process.stdout.write(`scrypt:${salt.toString('base64url')}:${hash}\n`);
}
