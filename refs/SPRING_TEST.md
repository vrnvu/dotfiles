Spring Testing 

```
Integration tests (slow)        ▲
  @SpringBootTest              /|\
                              / | \
Slice tests (medium)         /  |  \
  @WebMvcTest               /   |   \
                           /    |    \
Unit tests (fast)         /_____|_____\
  Plain Java
```

Unit tests: No Spring, instant (<1s)
Slice tests: @WebMvcTest, web layer context (seconds)
Integration tests: @SpringBootTest, full context (10s+)

Unit tests 

```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    
    public UserDto create(CreateUserRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new DuplicateEmailException("Email already exists");
        }
        
        var user = new User();
        user.setEmail(request.email());
        user.setPassword(passwordEncoder.encode(request.password()));
        return UserMapper.toDto(userRepository.save(user));
    }
}

// Pure unit test - NO Spring annotations
class UserServiceTest {
    private UserRepository userRepository;
    private PasswordEncoder passwordEncoder;
    private UserService userService;
    
    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        passwordEncoder = mock(PasswordEncoder.class);
        userService = new UserService(userRepository, passwordEncoder);
    }
    
    @Test
    void shouldCreateUser() {
        var request = new CreateUserRequest("test@example.com", "password123");
        var user = new User();
        user.setId(UUID.randomUUID());
        user.setEmail(request.email());
        
        when(userRepository.existsByEmail(request.email())).thenReturn(false);
        when(passwordEncoder.encode(request.password())).thenReturn("encoded");
        when(userRepository.save(any(User.class))).thenReturn(user);
        
        var result = userService.create(request);
        
        assertThat(result.email()).isEqualTo("test@example.com");
    }
    
    @Test
    void shouldThrowWhenEmailExists() {
        var request = new CreateUserRequest("test@example.com", "password123");
        when(userRepository.existsByEmail(request.email())).thenReturn(true);
        
        assertThatThrownBy(() -> userService.create(request))
            .isInstanceOf(DuplicateEmailException.class);
        
        verify(userRepository, never()).save(any());
    }
}
```

Why: Manual construction = full control; instant startup; no context overhead; tests business logic only.

Mockito rules (when to mock, when not to)

```java
// MOCK: External dependencies, I/O, slow operations
mock(UserRepository.class)
mock(RestClient.class)
mock(RedisTemplate.class)

// DON'T MOCK: Simple objects, DTOs, records
var request = new CreateUserRequest("test@example.com", "password123");  // Real object

// DON'T MOCK: Simple logic, pure functions
var result = calculator.calculate(100);  // No mocking needed

// USE FAKES: When mocking gets complex
class FakeEmailService implements EmailService {
    List<String> sentEmails = new ArrayList<>();
    
    public void send(String email) {
        sentEmails.add(email);
    }
}
```

Why: Mock I/O and external systems; use real objects for data; fakes for complex interactions.

Controller tests (@WebMvcTest slice)

```java
@WebMvcTest(UserApiController.class)
class UserApiControllerTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @MockBean
    private UserService userService;
    
    @Test
    void shouldGetUser() throws Exception {
        var userId = UUID.randomUUID();
        var userDto = new UserDto(userId, "test@example.com");
        when(userService.findById(userId)).thenReturn(userDto);
        
        mockMvc.perform(get("/api/v1/users/{id}", userId))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.email").value("test@example.com"));
    }
    
    @Test
    void shouldReturn404WhenNotFound() throws Exception {
        var userId = UUID.randomUUID();
        when(userService.findById(userId))
            .thenThrow(new EntityNotFoundException("User not found"));
        
        mockMvc.perform(get("/api/v1/users/{id}", userId))
            .andExpect(status().isNotFound())
            .andExpect(jsonPath("$.detail").value("User not found"));
    }
    
    @Test
    void shouldValidateRequest() throws Exception {
        var invalidRequest = """
            {
                "email": "not-an-email",
                "password": "123"
            }
            """;
        
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(invalidRequest))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.errors.email").exists());
    }
}
```

Why: @WebMvcTest loads only web layer; fast; no Redis/services loaded; tests HTTP mapping only.

MVC controller tests (with session)

```java
@WebMvcTest(AuthController.class)
class AuthControllerTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @MockBean
    private UserService userService;
    
    @MockBean
    private OktaService oktaService;
    
    @Test
    void shouldShowLoginPage() throws Exception {
        mockMvc.perform(get("/auth/login"))
            .andExpect(status().isOk())
            .andExpect(view().name("login"));
    }
    
    @Test
    void shouldRedirectToSignupWhenNewUser() throws Exception {
        var oktaUser = new OktaUser("user123", "test@example.com");
        when(oktaService.authenticate("auth-code")).thenReturn(oktaUser);
        when(userService.exists("test@example.com")).thenReturn(false);
        
        mockMvc.perform(get("/auth/oauth2/callback")
                .param("code", "auth-code")
                .param("state", "csrf-state")
                .sessionAttr("oauth2State", "csrf-state"))
            .andExpect(status().is3xxRedirection())
            .andExpect(redirectedUrl("/auth/signup"));
    }
}
```

Why: Test HTML rendering; test session interactions; test redirects; mock Okta service.

Exclude security filters (when needed)

```java
@WebMvcTest(UserApiController.class)
@AutoConfigureMockMvc(addFilters = false)
class MinimalControllerTest {
    // No security filters, CSRF, etc.
    // Tests pure controller logic
}
```

Why: Sometimes you want to test controller logic without security overhead; use sparingly.

Testing with authentication

```java
@WebMvcTest(UserApiController.class)
class SecurityTest {
    
    @Autowired
    private MockMvc mockMvc;
    
    @MockBean
    private UserService userService;
    
    @Test
    @WithMockUser(username = "test@example.com", roles = "USER")
    void shouldAccessWithAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/users/profile"))
            .andExpect(status().isOk());
    }
    
    @Test
    void shouldReturn401WhenNotAuthenticated() throws Exception {
        mockMvc.perform(get("/api/v1/users/profile"))
            .andExpect(status().isUnauthorized());
    }
    
    @Test
    @WithOAuth2Login(attributes = { @Attribute(key = "email", value = "test@example.com") })
    void shouldAccessWithOktaAuth() throws Exception {
        mockMvc.perform(get("/api/v1/users/profile"))
            .andExpect(status().isOk());
    }
}
```

Why: @WithMockUser for simple auth; @WithOAuth2Login for Okta/OAuth2; test authorization rules.

Repository tests (Redis, custom clients)

```java
// Unit test - mock Redis
class UserRepositoryTest {
    private RedisTemplate<String, User> redisTemplate;
    private UserRepository userRepository;
    
    @BeforeEach
    void setUp() {
        redisTemplate = mock(RedisTemplate.class);
        userRepository = new UserRepository(redisTemplate);
    }
    
    @Test
    void shouldFindById() {
        var userId = UUID.randomUUID();
        var user = new User(userId, "test@example.com");
        var ops = mock(ValueOperations.class);
        
        when(redisTemplate.opsForValue()).thenReturn(ops);
        when(ops.get("user:" + userId)).thenReturn(user);
        
        var found = userRepository.findById(userId);
        
        assertThat(found).isPresent();
    }
}

// Integration test - real Redis
@SpringBootTest
@Testcontainers
class UserRepositoryIntegrationTest {
    
    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
        .withExposedPorts(6379);
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
    }
    
    @Autowired
    private UserRepository userRepository;
    
    @Test
    void shouldSaveAndRetrieve() {
        var user = new User(UUID.randomUUID(), "test@example.com");
        
        userRepository.save(user);
        var found = userRepository.findById(user.getId());
        
        assertThat(found).isPresent();
        assertThat(found.get().getEmail()).isEqualTo("test@example.com");
    }
}
```

Why: Unit test with mocks (fast); integration test with Testcontainers (real Redis, catches serialization issues).

Integration tests (full context, use sparingly)

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class UserIntegrationTest {
    
    @Container
    static GenericContainer<?> redis = new GenericContainer<>("redis:7-alpine")
        .withExposedPorts(6379);
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
    }
    
    @Autowired
    private TestRestTemplate restTemplate;
    
    @Autowired
    private UserRepository userRepository;
    
    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }
    
    @Test
    void shouldCreateAndRetrieveUser() {
        var request = new CreateUserRequest("test@example.com", "password123");
        
        var createResponse = restTemplate.postForEntity(
            "/api/v1/users", 
            request, 
            UserDto.class
        );
        
        assertThat(createResponse.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        
        var userId = createResponse.getBody().id();
        var getResponse = restTemplate.getForEntity(
            "/api/v1/users/" + userId,
            UserDto.class
        );
        
        assertThat(getResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(getResponse.getBody().email()).isEqualTo("test@example.com");
    }
}
```

Why: Tests full request→response flow; all beans wired; real Redis; slow; use for critical paths only.

Test data builders

```java
class UserTestBuilder {
    private UUID id = UUID.randomUUID();
    private String email = "test@example.com";
    private String password = "encoded";
    
    public static UserTestBuilder aUser() {
        return new UserTestBuilder();
    }
    
    public UserTestBuilder withEmail(String email) {
        this.email = email;
        return this;
    }
    
    public User build() {
        var user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setPassword(password);
        return user;
    }
}

// Usage
@Test
void test() {
    var user = aUser()
        .withEmail("custom@example.com")
        .build();
}
```

Why: Reduces boilerplate; readable; reusable; defaults handled.

Testing async operations

```java
@Service
public class EmailService {
    
    @Async
    public CompletableFuture<Void> sendEmail(String to) {
        // Send email
        return CompletableFuture.completedFuture(null);
    }
}

// Unit test
@Test
void shouldSendEmail() throws Exception {
    var service = new EmailService();
    var future = service.sendEmail("test@example.com");
    future.get(1, TimeUnit.SECONDS);  // Wait
    // Verify outcome, not mechanism
}

// Integration test with Awaitility
@SpringBootTest
class AsyncIntegrationTest {
    
    @Autowired
    private EmailService emailService;
    
    @Test
    void shouldPersistEmail() {
        emailService.sendEmail("test@example.com");
        
        await().atMost(Duration.ofSeconds(5))
            .untilAsserted(() -> {
                // Assert side effects
            });
    }
}
```

Why: Test outcome, not async mechanism; Awaitility for polling; avoid Thread.sleep.

When service has too many dependencies

```java
// PROBLEM: 10+ dependencies
@Service
public class OrderService {
    private final OrderRepository repo;
    private final UserService userService;
    private final PaymentService paymentService;
    private final InventoryService inventoryService;
    private final EmailService emailService;
    // ... more
}

// SOLUTION 1: Refactor (split responsibilities)
@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository repo;
    private final OrderValidator validator;
    private final OrderEventPublisher eventPublisher;
}

// SOLUTION 2: Test critical logic only with unit tests
@Test
void shouldCalculateTotal() {
    var calculator = new OrderCalculator();
    var result = calculator.calculate(items);
    assertThat(result).isEqualTo(100.0);
}

// SOLUTION 3: Integration test for wiring
@SpringBootTest
@Test
void shouldProcessOrderEndToEnd() {
    // Test full flow, not individual logic
}
```

Why: 10 mocks = design smell. Refactor first, test second.

Common test anti-patterns

```java
// BAD: Testing implementation
verify(userRepository).save(any());
verify(emailService).send(any());

// GOOD: Testing behavior
assertThat(result.email()).isEqualTo(expected);

// BAD: Mocking simple objects
var request = mock(CreateUserRequest.class);

// GOOD: Real objects
var request = new CreateUserRequest("test@example.com", "password");

// BAD: Returning null
public User findById() { return null; }

// GOOD: Optional or throw
public Optional<User> findById() { return Optional.empty(); }
throw new EntityNotFoundException();

// BAD: 50+ lines of setup
@BeforeEach
void setUp() {
    // Massive setup
}

// GOOD: Builders or split test classes
var user = aUser().withEmail("test@example.com").build();
```

Test organization

```
src/test/java/com/yourapp/
├── user/
│   ├── UserServiceTest.java           # Unit test (no Spring)
│   ├── UserApiControllerTest.java     # @WebMvcTest
│   └── UserIntegrationTest.java       # @SpringBootTest
├── auth/
│   ├── AuthControllerTest.java        # @WebMvcTest
│   └── AuthFlowIntegrationTest.java   # @SpringBootTest
└── fixtures/
    ├── UserTestBuilder.java
    └── TestContainers.java
```

Why: Organize by feature/domain; naming convention (*IntegrationTest) is the only separation needed; no artificial unit/slice/integration folders.

Shared test config

```java
@TestConfiguration
public class TestConfig {
    
    @Bean
    @Primary
    public EmailService testEmailService() {
        return new NoOpEmailService();  // Don't send emails in tests
    }
    
    @Bean
    public Clock fixedClock() {
        return Clock.fixed(Instant.parse("2025-01-01T00:00:00Z"), ZoneOffset.UTC);
    }
}

@SpringBootTest
@Import(TestConfig.class)
class UserIntegrationTest {
    // Uses test beans
}
```

Why: Override expensive beans; deterministic time; shared across integration tests.

Test execution separation (Gradle)

```groovy
// build.gradle
test {
    useJUnitPlatform()
    
    // Skip @SpringBootTest if -PskipIntegration flag is set
    if (project.hasProperty('skipIntegration')) {
        exclude '**/*IntegrationTest.class'
    }
}
```

File naming convention:

```java
// Unit tests - instant
UserServiceTest.java           // No Spring context

// Slice tests - seconds (web layer context)
UserApiControllerTest.java     // @WebMvcTest
AuthControllerTest.java        // @WebMvcTest

// Integration tests - slow (full context + Testcontainers)
UserIntegrationTest.java       // @SpringBootTest
AuthFlowIntegrationTest.java  // @SpringBootTest
```

Commands:

```bash
./gradlew build                      # Build + all tests (unit + slice + integration)
./gradlew test -PskipIntegration     # Skip @SpringBootTest (fast feedback)
./gradlew test                       # All tests
```

Why: Default runs everything; -PskipIntegration for fast local feedback; naming convention (*IntegrationTest) = no manual tags needed.

Essential test dependencies

```kotlin
// build.gradle.kts
dependencies {
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.testcontainers:testcontainers")
    testImplementation("org.testcontainers:junit-jupiter")
    testImplementation("org.testcontainers:redis")
    testImplementation("org.testcontainers:localstack")
    testImplementation("org.awaitility:awaitility")
}
```

Test guidelines (summary)

1. **No Spring for unit tests** - Manual construction, instant startup
2. **@WebMvcTest for controllers** - Fast enough to run with unit tests
3. **@SpringBootTest only for integration** - Name as *IntegrationTest
4. **Testcontainers for integration** - Real Redis, real dependencies
5. **Mock I/O only** - Not DTOs, not value objects
6. **Test behavior** - Not implementation details
7. **Builders for data** - Reduce boilerplate
8. **Refactor over mocking** - 10 mocks = design problem
9. **Naming convention** - *IntegrationTest for @SpringBootTest, no manual tags
10. **Skip integration locally** - ./gradlew test -PskipIntegration

Quick troubleshooting

- Tests timeout → check async code, Testcontainers not started
- Context won't start → check @MockBean matches actual beans, missing Redis config
- Flaky tests → shared state, execution order, time/randomness
- OutOfMemoryError → too many @SpringBootTest contexts, consolidate
- Tests pass but app fails → integration test gap

Rule: If you need @SpringBootTest "because too many dependencies", refactor first, test second.
