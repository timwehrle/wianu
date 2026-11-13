const root = document.documentElement;
const marker = 'data-wianu-interaction-blocked';
if (blocked) {
    if (!root.hasAttribute(marker)) {
        globalThis.wianuPointerEvents = {
            value: root.style.getPropertyValue('pointer-events'),
            priority: root.style.getPropertyPriority('pointer-events')
        };
        root.setAttribute(marker, '');
    }
    root.style.setProperty('pointer-events', 'none', 'important');
} else if (root.hasAttribute(marker)) {
    const previous = globalThis.wianuPointerEvents ?? {
        value: '',
        priority: ''
    };
    root.style.setProperty('pointer-events', previous.value, previous.priority);
    root.removeAttribute(marker);
    delete globalThis.wianuPointerEvents;
}
