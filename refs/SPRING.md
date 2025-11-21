Spring Boot

Core principles

```java
// 1. Constructor injection only (never @Autowired fields)
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository repository;  // final + @RequiredArgsConstructor
}

// 2. DTOs everywhere (never expose entities)
public record UserDto(UUID id, String email) {}

// 3. Validation on inputs
public void create(@Valid CreateUserRequest request) {}

// 4. Optional or throw (never return null)
public Optional<User> findById(UUID id) {}
// OR
throw new EntityNotFoundException("User not found");

// 5. Transactions with readOnly default
@Service
@Transactional(readOnly = true)  // Default
public class UserService {
    @Transactional  // Override for writes
    public void create() {}
}
```

REST API controllers

```java
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserApiController {
    private final UserService userService;
    
    @GetMapping("/{id}")
    public ResponseEntity<UserDto> getUser(@PathVariable UUID id) {
        return ResponseEntity.ok(userService.findById(id));
    }
    
    @PostMapping
    public ResponseEntity<UserDto> create(@Valid @RequestBody CreateUserRequest request) {
        var user = userService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(user);
    }
    
    @GetMapping("/profile")
    public UserDto profile(@AuthenticationPrincipal OidcUser user) {
        return userService.findByEmail(user.getEmail());
    }
}
```

Why: Stateless; JWT/Okta tokens; returns JSON; use @AuthenticationPrincipal for current user.

MVC controllers (HTML rendering with sessions)

```java
@Controller
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {
    private final UserService userService;
    
    @GetMapping("/login")
    public String loginPage(
            @RequestParam(required = false) String error,
            HttpSession session,
            Model model) {
        
        // Read from session (set during OAuth callback)
        if (session.getAttribute("loginError") != null) {
            model.addAttribute("error", session.getAttribute("loginError"));
            session.removeAttribute("loginError");  // Clean up immediately
        }
        
        return "login";  // Returns HTML view
    }
    
    @GetMapping("/oauth2/callback")
    public String oauth2Callback(
            @RequestParam String code,
            @RequestParam String state,
            HttpSession session) {
        
        // Verify CSRF state
        var expectedState = (String) session.getAttribute("oauth2State");
        if (!state.equals(expectedState)) {
            session.setAttribute("loginError", "Invalid state");
            return "redirect:/auth/login";
        }
        
        try {
            var user = oktaService.authenticate(code);
            
            // Store minimal data for next page
            session.setAttribute("userId", user.getId());
            session.setAttribute("email", user.getEmail());
            session.setMaxInactiveInterval(300);  // 5 min timeout
            
            if (!userService.exists(user.getEmail())) {
                return "redirect:/auth/signup";
            }
            
            return "redirect:/dashboard";
            
        } catch (Exception e) {
            session.setAttribute("loginError", "Authentication failed");
            return "redirect:/auth/login";
        } finally {
            session.removeAttribute("oauth2State");  // Always clean up
        }
    }
    
    @GetMapping("/signup")
    public String signupPage(HttpSession session, Model model) {
        var email = (String) session.getAttribute("email");
        if (email == null) {
            return "redirect:/auth/login";
        }
        
        model.addAttribute("email", email);
        return "signup";
    }
    
    @PostMapping("/signup")
    public String completeSignup(
            @Valid @ModelAttribute SignupRequest request,
            HttpSession session) {
        
        var userId = (String) session.getAttribute("userId");
        userService.completeSignup(userId, request);
        
        // Clean up session after successful signup
        session.removeAttribute("userId");
        session.removeAttribute("email");
        
        return "redirect:/dashboard";
    }
}
```

Why: @Controller for HTML views; sessions for multi-step auth flows; clean up session immediately after use; short timeouts for auth flows.

Session configuration (Redis-backed)

```yaml
# application.yml
spring:
  session:
    store-type: redis
    redis:
      namespace: myapp:session
    timeout: 30m
  
  data:
    redis:
      host: localhost
      port: 6379
      password: ${REDIS_PASSWORD}
      ssl:
        enabled: true
  
  security:
    oauth2:
      client:
        registration:
          okta:
            client-id: ${OKTA_CLIENT_ID}
            client-secret: ${OKTA_CLIENT_SECRET}
            scope: openid,profile,email
        provider:
          okta:
            issuer-uri: https://your-domain.okta.com/oauth2/default

server:
  servlet:
    session:
      cookie:
        secure: true      # HTTPS only
        http-only: true   # No JavaScript access
        same-site: lax    # CSRF protection
        max-age: 1800     # 30 minutes
```

Why: Redis for distributed sessions (no sticky sessions needed); secure cookies; short session timeout for security.

```java
// Session config
@Configuration
@EnableRedisHttpSession(maxInactiveIntervalInSeconds = 1800)
public class SessionConfig {
    
    @Bean
    public RedisSerializer<Object> springSessionDefaultRedisSerializer() {
        return new GenericJackson2JsonRedisSerializer();
    }
}
```

Why: Redis-backed sessions scale horizontally; JSON serialization for debugging; 30-min timeout.

Security configuration

```java
@Configuration
public class SecurityConfig {
    
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/", "/auth/login", "/auth/signup", "/health/**").permitAll()
                .requestMatchers("/api/**").authenticated()  // REST APIs
                .anyRequest().authenticated()  // MVC pages
            )
            .oauth2Login(oauth2 -> oauth2
                .loginPage("/auth/login")
                .defaultSuccessUrl("/dashboard")
            )
            .logout(logout -> logout
                .logoutUrl("/auth/logout")
                .logoutSuccessUrl("/")
                .invalidateHttpSession(true)
                .deleteCookies("JSESSIONID")
            )
            .sessionManagement(session -> session
                .maximumSessions(1)
                .maxSessionsPreventsLogin(false)  // Kick old sessions
            )
            .build();
    }
}
```

Why: Public login/signup pages; authenticated for everything else; single session per user; Redis handles the rest.

Exception handling (consistent errors)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(EntityNotFoundException.class)
    public ProblemDetail handleNotFound(EntityNotFoundException ex) {
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND,
            ex.getMessage()
        );
    }
    
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        var problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.BAD_REQUEST,
            "Validation failed"
        );
        var errors = ex.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.toMap(
                FieldError::getField,
                f -> f.getDefaultMessage()
            ));
        problem.setProperty("errors", errors);
        return problem;
    }
}
```

Why: ProblemDetail (RFC 7807) is the standard; works for REST APIs; MVC controllers can catch and redirect.

Validation

```java
public record CreateUserRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8, max = 100) String password
) {}

public record SignupRequest(
    @NotBlank @Size(min = 2, max = 50) String firstName,
    @NotBlank @Size(min = 2, max = 50) String lastName
) {}
```

Why: Records for immutable DTOs; declarative validation; fail fast.

Service layer

```java
@Service
@Transactional(readOnly = true)
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    
    public UserDto findById(UUID id) {
        return userRepository.findById(id)
            .map(UserMapper::toDto)
            .orElseThrow(() -> new EntityNotFoundException("User not found"));
    }
    
    public UserDto findByEmail(String email) {
        return userRepository.findByEmail(email)
            .map(UserMapper::toDto)
            .orElseThrow(() -> new EntityNotFoundException("User not found"));
    }
    
    @Transactional
    public UserDto create(CreateUserRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new DuplicateEmailException("Email already exists");
        }
        
        var user = new User();
        user.setEmail(request.email());
        user.setPassword(passwordEncoder.encode(request.password()));
        
        return UserMapper.toDto(userRepository.save(user));
    }
    
    @Transactional
    public void completeSignup(String userId, SignupRequest request) {
        var user = userRepository.findById(UUID.fromString(userId))
            .orElseThrow(() -> new EntityNotFoundException("User not found"));
        
        user.setFirstName(request.firstName());
        user.setLastName(request.lastName());
        userRepository.save(user);
    }
}
```

Why: Class-level readOnly; explicit write transactions; throw specific exceptions; mappers keep entities internal.

HTTP client (external APIs)

```java
@Configuration
public class HttpClientConfig {
    
    @Bean
    public RestClient oktaClient(RestClient.Builder builder) {
        return builder
            .baseUrl("https://your-domain.okta.com")
            .defaultHeader("Accept", "application/json")
            .build();
    }
}

@Service
@RequiredArgsConstructor
public class OktaService {
    private final RestClient oktaClient;
    
    public OktaUser getUserInfo(String accessToken) {
        return oktaClient.get()
            .uri("/oauth2/v1/userinfo")
            .header("Authorization", "Bearer " + accessToken)
            .retrieve()
            .body(OktaUser.class);
    }
}
```

Why: RestClient over RestTemplate; separate beans per service; clear configuration.

Configuration (type-safe)

```java
@ConfigurationProperties(prefix = "app")
public record AppProperties(
    String name,
    Duration sessionTimeout,
    Okta okta,
    Redis redis
) {
    public record Okta(String issuerUri, String clientId) {}
    public record Redis(String host, int port) {}
}

@SpringBootApplication
@EnableConfigurationProperties(AppProperties.class)
public class Application {}
```

Why: Records for immutable config; Duration over int; type-safe; validated at startup.

Observability

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,prometheus,info
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
  metrics:
    tags:
      application: ${spring.application.name}
      environment: ${ENV:local}
```

```java
@RestController
class HealthController {
    
    @GetMapping("/health/liveness")
    public ResponseEntity<Void> liveness() {
        return ResponseEntity.ok().build();
    }
    
    @GetMapping("/health/readiness")
    public ResponseEntity<Void> readiness(@Autowired RedisConnectionFactory redis) {
        try {
            redis.getConnection().ping();
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }
    }
}
```

Why: Separate liveness (process alive) from readiness (dependencies healthy); check Redis in readiness.

What to avoid

```java
// NEVER: Field injection
@Autowired private UserService service;

// NEVER: Expose entities in controllers
public User getUser() {}

// NEVER: Return null
public User findById() { return null; }

// NEVER: Catch generic Exception
catch (Exception e) {}

// NEVER: Store complex objects in session
Map<String, Object> customMap = new HashMap<>();
session.setAttribute("myMap", customMap);

// NEVER: Skip validation
public void create(CreateUserRequest request) {}  // Missing @Valid

// NEVER: Manual transaction management
entityManager.getTransaction().begin();

// NEVER: Use RestTemplate
RestTemplate restTemplate = new RestTemplate();  // Use RestClient

// NEVER: Long-lived sessions for auth flows
session.setMaxInactiveInterval(3600);  // Too long for auth

// NEVER: Store sensitive data in session
session.setAttribute("password", pwd);  // Never
```

Spring 4.0 readiness (when migrating)

```yaml
# Requires Java 21+
java.version=21

# Enable virtual threads
spring:
  threads:
    virtual:
      enabled: true
```

```java
// Remove deprecated code
WebSecurityConfigurerAdapter  // Gone in 4.0
RestTemplate                 // Use RestClient
```

Essential application.yml

```yaml
spring:
  application:
    name: myapp
  
  threads:
    virtual:
      enabled: true  # Java 21+
  
  session:
    store-type: redis
    timeout: 30m
  
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD}
  
  security:
    oauth2:
      client:
        registration:
          okta:
            client-id: ${OKTA_CLIENT_ID}
            client-secret: ${OKTA_CLIENT_SECRET}
            scope: openid,profile,email
        provider:
          okta:
            issuer-uri: ${OKTA_ISSUER_URI}

server:
  servlet:
    session:
      cookie:
        secure: true
        http-only: true
        same-site: lax
        max-age: 1800

management:
  endpoints:
    web:
      exposure:
        include: health,prometheus,info
  metrics:
    tags:
      application: ${spring.application.name}

logging:
  level:
    org.springframework.security: DEBUG  # Only in dev
    com.yourpackage: INFO
```

Troubleshooting

- Session not persisting → Check Redis connection; verify @EnableRedisHttpSession
- 401 on API calls → Check JWT token; verify SecurityFilterChain matchers
- Session lost after restart → Expected with Redis; check Redis persistence config
- CSRF errors → Disable for REST APIs; keep for MVC forms
- Login loop → Check session cookie settings (secure, same-site)
- Slow login → Check Redis latency; verify network to Okta

Dependencies (build.gradle.kts)

```kotlin
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-oauth2-client")
    implementation("org.springframework.boot:spring-boot-starter-data-redis")
    implementation("org.springframework.session:spring-session-data-redis")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    
    compileOnly("org.projectlombok:lombok")
    annotationProcessor("org.projectlombok:lombok")
    
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.testcontainers:testcontainers")
    testImplementation("org.testcontainers:junit-jupiter")
}
```

Quick reference

- @RestController → REST API, returns JSON
- @Controller → MVC, returns HTML views
- @AuthenticationPrincipal → Get current Okta user
- @Transactional(readOnly=true) → Default for reads
- @Transactional → Override for writes
- ProblemDetail → Standard error format
- RestClient → Modern HTTP client
- Records → DTOs and config
- Redis sessions → Distributed, scalable
- Clean up sessions → removeAttribute() ASAP

Resources

- Spring Boot 4.0 migration: https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.0-Migration-Guide
- Spring Security: https://docs.spring.io/spring-security/reference/index.html
- Okta Spring Boot: https://developer.okta.com/docs/guides/sign-into-web-app-redirect/spring-boot/main/
