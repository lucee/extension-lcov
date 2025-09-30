# Java Integration in Lucee - Key Concepts

Based on Lucee documentation: https://docs.lucee.org/categories/java.html

## JavaSettings Configuration

JavaSettings can be configured at multiple levels:

### In Application.cfc
```cfml
this.javasettings = {
	maven: [ ... ],
	loadPaths: [ "/path/to/libs/" ],
	bundlePaths: [ "/path/to/bundles/" ],
	loadCFMLClassPath: true  // Load Lucee's internal classpath
};
```

### In Individual Components
```cfml
component javaSettings='{
	"maven": [
		{
			"groupId": "commons-beanutils",
			"artifactId": "commons-beanutils",
			"version": "1.9.4"
		}
	],
	"loadCFMLClassPath": true
}' {
	// Component logic
}
```

## Key Feature: loadCFMLClassPath

When `loadCFMLClassPath: true` is set, the component can access Java classes from Lucee's internal classpath, including:
- Lucee's bundled libraries
- OSGi bundles
- Core Java classes used by Lucee itself (like ASM)

**Important**: This setting is inherited by the component's classloader, but **NOT automatically inherited by components it instantiates**.

## Using Import Statements

```cfml
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassVisitor;
import java.util.*;
```

## Implementing vs Extending Java Classes

### Implementing Interfaces (Supported)
```cfml
component implements="java:java.util.Map" {
	// Implement interface methods
	public function get(key) { ... }
	public function put(key, value) { ... }
}
```

### Extending Classes (Supported with Limitations)
```cfml
component extends="org.objectweb.asm.ClassVisitor" javasettings='{loadCFMLClassPath: true}' {
	// Must call super.init() in init()
	public function init() {
		super.init(apiVersion);
		return this;
	}
}
```

**Limitations when extending**:
1. The parent Java class must be on the classpath (use `loadCFMLClassPath` or `maven`)
2. Components created via `new` from parent component **do not inherit javasettings**
3. Each component that extends a Java class needs its own `javasettings`

## The Problem with Nested Components

When you do:
```cfml
// In BytecodeAnalyzer.cfc with javasettings
var visitor = new asm.LineNumberCollector(lineNumbers);
```

The `LineNumberCollector` component is loaded with a **different classloader** that may not have access to `org.objectweb.asm.ClassVisitor`, even though the parent has `loadCFMLClassPath: true`.

### Solution Approaches

#### 1. Each Component Declares Its Own JavaSettings
```cfml
// LineNumberCollector.cfc
component extends="org.objectweb.asm.ClassVisitor" javasettings='{loadCFMLClassPath: true}' {
	// Each component explicitly declares it needs CFML classpath
}
```

#### 2. Use Java Proxies via implements (Recommended for complex cases)
Instead of extending, implement the interface:
```cfml
component implements="java:org.objectweb.asm.ClassVisitor" {
	// Implement required methods
}
```

#### 3. Create Java Classes Directly (For Simple Cases)
Use `createObject("java", ...)` with anonymous inner classes or lambda-style approaches.

## Classloader Isolation

Lucee maintains a pool of classloaders based on hash of javasettings:
- Same settings = same classloader (cached)
- Different settings = different classloader
- Components with no settings = default classloader

This means child components need explicit javasettings to access the same classpath as parent.

## Best Practices

1. **Declare javasettings explicitly** on every component that extends/implements Java classes
2. **Use `loadCFMLClassPath: true`** when working with Lucee's internal libraries (ASM, etc.)
3. **Keep javasettings consistent** across related components to share classloaders
4. **Prefer implements over extends** when possible - it's more flexible
5. **Test classloader issues** by checking if Java classes are accessible in each component

## Our Current Issue

`BytecodeAnalyzer.cfc` has `loadCFMLClassPath: true`, so it can create `org.objectweb.asm.ClassReader`.

But when it does `new asm.LineNumberCollector()`, that component tries to extend `org.objectweb.asm.ClassVisitor` and fails because:
- `LineNumberCollector` has `loadCFMLClassPath: true` in its definition
- But Lucee might be loading it with a different classloader context

**Fix**: Ensure all components in the asm/ folder have identical javasettings to share the classloader.