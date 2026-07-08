# Contexts and Steps Guide

## Table of Contents

- [Overview](#overview)
- [Core Concepts](#core-concepts)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)
- [Navigation and Flow Control](#navigation-and-flow-control)
- [Function Restrictions](#function-restrictions)
- [Real-World Examples](#real-world-examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Migration from POM](#migration-from-pom)

## Overview

The **Contexts and Steps** system enhances traditional Prompt Object Model (POM) prompts in SignalWire AI agents by adding structured workflows on top of your base prompt. Instead of just defining a single prompt, you create workflows with explicit steps, navigation rules, and completion criteria. Steps can restrict which SWAIG (SignalWire AI Gateway) functions are available at each stage of the conversation.

### Key Benefits

- **Structured Workflows**: Define clear, step-by-step processes
- **Explicit Navigation**: Control exactly where users can go next
- **Function Restrictions**: Limit AI tool access per step
- **Completion Criteria**: Define clear progression requirements
- **Context Isolation**: Separate different conversation flows
- **Debugging**: Easier to trace and debug complex interactions

### When to Use Contexts vs Traditional Prompts

**Use Contexts and Steps when:**
- Building multi-step workflows (onboarding, support tickets, applications)
- Need explicit navigation control between conversation states
- Want to restrict function access based on conversation stage
- Building complex customer service or troubleshooting flows
- Creating guided experiences with clear progression

**Use Traditional Prompts when:**
- Building simple, freeform conversational agents
- Want maximum flexibility in conversation flow
- Creating general-purpose assistants
- Prototyping or building simple proof-of-concepts

## Core Concepts

### Contexts

A **Context** represents a conversation state or workflow area. Contexts can be:

- **Workflow Container**: Simple step organization without state changes
- **Context Switch**: Triggers conversation state changes when entered

Each context can define:

- **Steps**: Individual workflow stages within the context
- **Context Prompts**: Guidance that applies to all steps in the context  
- **Entry Parameters**: Control conversation state when context is entered
- **Navigation Rules**: Which other contexts can be accessed

### Context Entry Parameters

When entering a context, these parameters control conversation behavior:

- **`post_prompt`**: Override the agent's post prompt for this context
- **`system_prompt`**: Trigger conversation reset with new instructions
- **`consolidate`**: Summarize previous conversation in new prompt
- **`full_reset`**: Complete system prompt replacement vs injection
- **`user_prompt`**: Inject user message for context establishment

**Important**: If `system_prompt` is present, the context becomes a "Context Switch Context" that processes entry parameters like a `context_switch` SWAIG action. Without `system_prompt`, it's a "Workflow Container Context" that only organizes steps.

### Context Prompts

Contexts can have their own prompts (separate from entry parameters):

```ruby
# Simple string prompt
context.prompt = 'Context-specific guidance'

# POM-style sections
context.add_section('Department', 'Billing Department')
context.add_bullets('Services', %w[Payments Refunds] + ['Account inquiries'])
```

Context prompts provide guidance that applies to all steps within that context, creating a prompt hierarchy: Base Agent Prompt → Context Prompt → Step Prompt.

### Steps

A **Step** is a specific stage within a context. Each step defines:

- **Prompt Content**: What the AI says/does (text or POM sections)
- **Completion Criteria**: When the step is considered complete
- **Navigation Rules**: Where the user can go next
- **Function Access**: Which AI tools are available

### Navigation Control

The system provides fine-grained control over conversation flow:

- **Valid Steps**: Control movement within a context
- **Valid Contexts**: Control switching between contexts  
- **Implicit Navigation**: Automatic "next" step progression
- **Explicit Navigation**: User must explicitly choose next step

## Getting Started

### Basic Single-Context Workflow

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'Onboarding Assistant', route: '/onboarding')

# Define contexts (replaces traditional prompt setup)
contexts = agent.define_contexts

# Single context must be named "default"
workflow = contexts.add_context('default')

# Step 1: Welcome
workflow.add_step('welcome')
        .set_text("Welcome to our service! Let's get you set up. What's your name?")
        .set_step_criteria('User has provided their name')
        .set_valid_steps(%w[collect_email])

# Step 2: Collect Email
workflow.add_step('collect_email')
        .set_text('Thanks! Now I need your email address to create your account.')
        .set_step_criteria('Valid email address has been provided')
        .set_valid_steps(%w[confirm_details])

# Step 3: Confirmation
workflow.add_step('confirm_details')
        .set_text('Perfect! Let me confirm your details before we proceed.')
        .set_step_criteria('User has confirmed their information')
        .set_valid_steps(%w[complete])

# Step 4: Completion
workflow.add_step('complete')
        .set_text('All set! Your account has been created successfully.')
# No valid_steps = end of workflow

agent.run
```

### Multi-Context Workflow

```ruby
agent = SignalWire::AgentBase.new(name: 'Customer Service', route: '/service')

# Add skills for enhanced capabilities
agent.add_skill('datetime')
agent.add_skill('web_search', {
  'api_key'          => 'your-api-key',
  'search_engine_id' => 'your-engine-id'
})

contexts = agent.define_contexts

# Main triage context
triage = contexts.add_context('triage')
triage.add_step('greeting')
      .add_section('Current Task', "Understand the customer's need and route appropriately")
      .add_bullets('Required Information', [
        "Type of issue they're experiencing",
        'Urgency level of the problem',
        'Previous troubleshooting attempts'
      ])
      .set_step_criteria("Customer's need has been identified")
      .set_valid_contexts(%w[technical billing general])

# Technical support context
tech = contexts.add_context('technical')
tech.add_step('technical_help')
    .add_section('Current Task', 'Help diagnose and resolve technical issues')
    .add_section('Available Tools', 'Use web search and datetime functions for technical solutions')
    .set_functions(%w[web_search datetime])
    .set_step_criteria('Issue is resolved or escalated')
    .set_valid_contexts(%w[triage])

# Billing context (restricted functions for security)
billing = contexts.add_context('billing')
billing.add_step('billing_help')
       .set_text("I'll help with your billing question. For security, please provide your account verification.")
       .set_functions('none')
       .set_step_criteria('Billing issue is addressed')
       .set_valid_contexts(%w[triage])

# General inquiries context
general = contexts.add_context('general')
general.add_step('general_help')
       .set_text("I'm here to help with general questions. What can I assist you with?")
       .set_functions(%w[web_search datetime])
       .set_step_criteria('Question has been answered')
       .set_valid_contexts(%w[triage])

agent.run
```

## API Reference

### ContextBuilder

The main entry point for defining contexts and steps.

```ruby
# Get the builder
contexts = agent.define_contexts

# Create contexts
context = contexts.add_context(name) # => Context
```

### Context

Represents a conversation context or workflow state.

<!-- snippet: no-compile ruby interface reference (class with signature-only defs, no method bodies) -->
```ruby
class Context
  # Create a new step in this context
  def add_step(name) # => Step

  # Set which contexts can be accessed from this context
  def set_valid_contexts(contexts) # => Context

  # --- Context entry parameters ---

  # Override post prompt for this context
  def set_post_prompt(post_prompt) # => Context  (or: context.post_prompt = ...)

  # Trigger context switch with new system prompt
  def set_system_prompt(system_prompt) # => Context  (or: context.system_prompt = ...)

  # Consolidate conversation history when entering
  def set_consolidate(consolidate) # => Context  (or: context.consolidate = ...)

  # Full system prompt replacement vs injection
  def set_full_reset(full_reset) # => Context  (or: context.full_reset = ...)

  # Inject user message for context
  def set_user_prompt(user_prompt) # => Context  (or: context.user_prompt = ...)

  # --- Context prompts ---

  # Set simple string prompt for context
  def set_prompt(prompt) # => Context  (or: context.prompt = ...)

  # Add POM section to context prompt
  def add_section(title, body) # => Context

  # Add POM bullet section to context prompt
  def add_bullets(title, bullets) # => Context

  # --- Context isolation and fillers ---

  # Mark context as isolated (independent conversation state)
  def set_isolated(isolated) # => Context  (or: context.isolated = ...)

  # Set fillers spoken when entering this context (Hash of code => Array)
  def set_enter_fillers(fillers) # => Context  (or: context.enter_fillers = ...)

  # Set fillers spoken when exiting this context (Hash of code => Array)
  def set_exit_fillers(fillers) # => Context  (or: context.exit_fillers = ...)

  # Add enter fillers for a specific language
  def add_enter_filler(language_code, fillers) # => Context

  # Add exit fillers for a specific language
  def add_exit_filler(language_code, fillers) # => Context
end
```

#### Methods

- `add_step(name)`: Create and return a new Step
- `set_valid_contexts(contexts)`: Allow navigation to specified contexts
- `set_post_prompt(prompt)`: Override agent's post prompt for this context
- `set_system_prompt(prompt)`: Trigger context switch behavior (makes this a Context Switch Context)
- `set_consolidate(bool)`: Whether to consolidate conversation when entering
- `set_full_reset(bool)`: Complete vs partial context reset
- `set_user_prompt(prompt)`: User message to inject when entering context
- `set_prompt(text)`: Simple string prompt for context
- `add_section(title, body)`: Add POM section to context prompt
- `add_bullets(title, list)`: Add POM bullet section to context prompt
- `set_isolated(bool)`: Mark context as isolated (independent conversation state)
- `set_enter_fillers(dict)`: Set all enter fillers by language code
- `set_exit_fillers(dict)`: Set all exit fillers by language code
- `add_enter_filler(lang, list)`: Add enter fillers for a specific language
- `add_exit_filler(lang, list)`: Add exit fillers for a specific language

### Step

Represents a single step within a context workflow.

<!-- snippet: no-compile ruby interface reference (class with signature-only defs, no method bodies) -->
```ruby
class Step
  # --- Content definition (choose one approach) ---

  # Set direct text prompt (mutually exclusive with POM sections)
  def set_text(text) # => Step  (or: step.text = ...)

  # Add a POM-style section (mutually exclusive with set_text)
  def add_section(title, body) # => Step

  # Add a POM section with bullet points (mutually exclusive with set_text).
  # Note: the Ruby Step#add_bullets takes a section title plus the bullet
  # list — `add_bullets(title, bullets)`. There is no `numbered:` option.
  def add_bullets(title, bullets) # => Step

  # --- Flow control ---

  # Define completion criteria for this step
  def set_step_criteria(criteria) # => Step  (or: step.step_criteria = ...)

  # Set which steps can be accessed next in same context
  def set_valid_steps(steps) # => Step  (or: step.valid_steps = ...)

  # Set which contexts can be accessed from this step
  def set_valid_contexts(contexts) # => Step  (or: step.valid_contexts = ...)

  # --- Function restrictions ---

  # Restrict available functions ('none', [], or list of function names)
  def set_functions(functions) # => Step  (or: step.functions = ...)

  # --- Reset behavior when entering step ---

  # Reset system prompt when entering this step (pass the prompt text)
  def set_reset_system_prompt(prompt) # => Step

  # Reset user prompt when entering this step (pass the prompt text)
  def set_reset_user_prompt(prompt) # => Step

  # Consolidate conversation when entering this step (pass true/false)
  def set_reset_consolidate(val) # => Step

  # Full conversation reset when entering this step (pass true/false)
  def set_reset_full_reset(val) # => Step
end
```

#### Content Methods

**Option 1: Direct Text**
```ruby
step.set_text('Direct prompt text for the AI')
```

**Option 2: POM-Style Sections**
```ruby
step.add_section('Role', 'You are a helpful assistant')
    .add_section('Instructions', 'Help users with their questions')
    .add_bullets('Guidelines', ['Be friendly', 'Ask clarifying questions'])
```

**Note**: You cannot mix `set_text()` with `add_section()` in the same step.

#### Navigation Methods

```ruby
# Control step progression within context
step.valid_steps = %w[step1 step2]  # Can go to step1 or step2
step.valid_steps = []               # Cannot progress (dead end)
# No valid_steps assignment = implicit "next" step

# Control context switching
step.valid_contexts = %w[context1 context2]  # Can switch contexts
step.valid_contexts = []                      # Trapped in current context
# No valid_contexts assignment = inherit from context level
```

#### Function Restriction Methods

```ruby
# Allow specific functions only
step.functions = %w[datetime math]

# Block all functions
step.functions = 'none'

# No restriction (default - all agent functions available)
# (Don't assign step.functions at all)
```

## Navigation and Flow Control

### Step Navigation Rules

The `set_valid_steps()` method controls movement within a context:

```ruby
# Explicit step list - can only go to these steps
step.valid_steps = %w[review edit cancel]

# Empty list - dead end, cannot progress
step.valid_steps = []

# Not assigned - implicit "next" step progression
# (will go to the next step defined in the context)
```

### Context Navigation Rules

The `set_valid_contexts()` method controls switching between contexts:

```ruby
# Can switch to these contexts
step.valid_contexts = %w[billing technical general]

# Trapped in current context
step.valid_contexts = []

# Not assigned - inherit from context-level settings
```

### Navigation Inheritance

Context-level navigation settings are inherited by steps:

```ruby
# Set at context level
context.valid_contexts = %w[main help]

# All steps in this context can access main and help contexts
# unless overridden at step level
step.valid_contexts = %w[main]  # Override - only main allowed
```

### Complete Navigation Example

```ruby
contexts = agent.define_contexts

# Main context
main = contexts.add_context('main')
main.valid_contexts = %w[help settings]  # Context-level setting

main.add_step('welcome')
    .set_text('Welcome! How can I help you?')
    .set_valid_steps(%w[menu])  # Must go to menu
# Inherits context-level valid_contexts

main.add_step('menu')
    .set_text('Choose an option: 1) Help 2) Settings 3) Continue')
    .set_valid_contexts(%w[help settings main])  # Override context setting
# No valid_steps = this is a branching point

# Help context
help_ctx = contexts.add_context('help')
help_ctx.add_step('help_info')
        .set_text("Here's how to use the system...")
        .set_valid_contexts(%w[main])  # Can return to main

# Settings context
settings = contexts.add_context('settings')
settings.add_step('settings_menu')
        .set_text('Choose a setting to modify...')
        .set_valid_contexts(%w[main])  # Can return to main
```

## Function Restrictions

Control which AI tools/functions are available in each step for enhanced security and user experience.

### Function Restriction Levels

```ruby
# No restrictions (default) - all agent functions available
step  # Don't assign step.functions

# Allow specific functions only
step.functions = %w[datetime math web_search]

# Block all functions
step.functions = 'none'
```

### Security-Focused Example

```ruby
agent = SignalWire::AgentBase.new(name: 'Banking Assistant', route: '/banking')

# Add potentially sensitive functions
agent.add_skill('web_search', { 'api_key' => 'key', 'search_engine_id' => 'id' })
agent.add_skill('datetime')

contexts = agent.define_contexts

# Public context - full access
public = contexts.add_context('public')
public.add_step('welcome')
      .set_text('Welcome to banking support. Are you an existing customer?')
      .set_functions(%w[datetime web_search]) # Safe functions only
      .set_valid_contexts(%w[authenticated public])

# Authenticated context - restricted for security
auth = contexts.add_context('authenticated')
auth.add_step('account_access')
    .set_text('I can help with your account. What do you need assistance with?')
    .set_functions('none')          # No external functions for account data
    .set_valid_contexts(%w[public]) # Can log out
```

### Function Access Patterns

```ruby
# Progressive function access based on trust level
contexts = agent.define_contexts

# Low trust - limited functions
public = contexts.add_context('public')
public.add_step('initial_contact')
      .set_functions(%w[datetime]) # Only safe functions

# Medium trust - more functions
verified = contexts.add_context('verified')
verified.add_step('verified_user')
        .set_functions(%w[datetime web_search]) # Add search capability

# High trust - full access
authenticated = contexts.add_context('authenticated')
authenticated.add_step('full_access')
# No set_functions call = all functions available
```

## Step Modes

Steps can operate in two modes:

- **Normal Mode**: The step's text is injected as instructions. The AI follows those instructions, and the step completes based on criteria you define or by navigating to the next step.
- **Gather Info Mode**: The step collects structured information from the caller one question at a time, with zero tool artifacts in the LLM conversation history. Once all questions are answered, the step either auto-advances or returns to normal mode.

### Normal Mode

In normal mode, the step's text is injected as a system message with this structure:

```
[context prompt if any]

## Instructions to complete the Current Step
[your step text]

Do not mention to the user that you are following steps, or the names of the steps.
Do not ask the user any questions not explicitly related to these instructions.
Do not end the conversation when this step is complete.
[step criteria if any]
```

The step text supports `${variable}` expansion from `global_data` and prompt variables.

Step criteria tell the AI when a step is done. The AI evaluates the criteria and calls `next_step` when they're met:

```ruby
ctx.add_step('verify')
   .set_text("Verify the caller's identity.")
   .set_step_criteria(
     'The caller has provided their account number ' \
     'AND confirmed their date of birth.'
   )
   .set_valid_steps(%w[handle_request])
```

### Gather Info Mode

When an AI agent needs to collect structured information (name, address, account number, etc.), the traditional approach uses SWAIG functions -- the AI calls a function for each piece of data, which creates `tool_call` and `tool_result` entries in the conversation history. These tool artifacts confuse some models (especially reasoning models at low effort settings), waste tokens, and can cause the model to lose track of where it is in the collection flow.

Gather info mode solves this by using **dynamic step instruction re-injection**. Questions are presented one at a time by swapping out the system instruction, and answers are recorded via an internal function that routes through the system-log path -- producing **zero** tool_call/tool_result entries in the LLM-visible conversation history.

#### How It Works Internally

1. **Step entry**: When the AI enters a step with `gather_info`, the system switches to gather questioning mode.
2. **Preamble injection** (first question only): If the gather has a `prompt`, it's injected as a **persistent** system message for the entire gather sequence.
3. **Question injection**: A minimal system instruction is injected as a **clearable** message containing the question text, type hint, confirmation instructions, and any per-question prompt text.
4. **Tool lockdown**: During gather mode, **all normal functions are hidden** -- only `gather_submit` (an internal function) and any per-question `functions` are visible.
5. **Answer submission**: When the AI calls `gather_submit`, the answer is written to `global_data` and the next question's instruction is re-injected. The `gather_submit` call routes through the system-log path, so the LLM never sees tool_call/tool_result for it.
6. **Completion**: When all questions are answered, either:
   - The step auto-advances to the next sequential step (`completion_action="next_step"`)
   - The step jumps to a specific named step (`completion_action="step_name"`)
   - The step returns to normal mode with the regular step text, plus a note that gathered data is available (when `completion_action` is None)

Here's what the LLM conversation history looks like during gather mode:

```
[system] You are a travel assistant. You need to collect some details.    <- persistent preamble
[system] Ask the user: "What is your first name?"                        <- clearable, changes per question
         When you have the answer, call the gather_submit function.
         Do not ask the user any other questions.

[assistant] Hi there! I'm your travel assistant. What's your first name?
[user] Tony.
                                                        <- gather_submit recorded via system-log (invisible)
[system] Ask the user: "What is your last name?"        <- previous question instruction replaced
         ...

[assistant] Great, Tony! And your last name?
[user] Smith.
```

No tool_call/tool_result entries anywhere. Clean conversation history.

#### Basic Gather Example

```ruby
ctx.add_step('collect_info')
   .set_text('Help the caller with their request.')
   .set_gather_info(output_key: 'caller_info')
   .add_gather_question(key: 'first_name', question: 'What is your first name?')
   .add_gather_question(key: 'last_name',  question: 'What is your last name?')
   .add_gather_question(key: 'email',      question: 'What is your email address?')
```

This collects three pieces of information, stores them under `caller_info` in global_data, then returns to normal step mode with the step text "Help the caller with their request."

#### The Gather Prompt (Preamble)

The gather `prompt` is injected once as a persistent message when the first question begins:

```ruby
ctx.add_step('collect_profile')
   .set_text('Use the profile to recommend products.')
   .set_gather_info(
     output_key: 'profile',
     prompt:     'Welcome the caller and introduce yourself as a product specialist. ' \
                 'Explain that you need to ask a few quick questions to find the ' \
                 'best products for them. Be friendly and conversational.'
   )
   .add_gather_question(key: 'name',   question: 'What is your name?')
   .add_gather_question(key: 'budget', question: 'What is your budget?', type: 'number')
```

Without a gather `prompt`, the AI jumps straight into asking the first question with no introduction.

#### Question Types

Each question has a `type` that controls the JSON schema of the `answer` parameter in `gather_submit`:

```ruby
# String (default) - free text
.add_gather_question(key: 'name', question: 'What is your name?', type: 'string')

# Integer - whole numbers
.add_gather_question(key: 'age', question: 'How old are you?', type: 'integer')

# Number - decimal values
.add_gather_question(key: 'budget', question: 'What is your budget in dollars?', type: 'number')

# Boolean - yes/no questions
.add_gather_question(key: 'has_passport', question: 'Do you have a valid passport?', type: 'boolean')
```

#### Confirmation Flow

When `confirm=True`, the AI must read the answer back to the caller and get explicit confirmation before submitting:

<!-- snippet: no-compile ruby method-chain continuation fragment (leading `.method`) -->
```ruby
.add_gather_question(
  key:      'last_name',
  question: 'What is your last name?',
  type:     'string',
  confirm:  true
)
```

How it works:

1. The question instruction includes: "You MUST confirm the answer with the user before submitting."
2. The `gather_submit` function schema includes a required `confirmed_by_user` enum parameter.
3. If the AI calls `gather_submit` with `confirmed_by_user` set to `"false"`, the function rejects the submission and tells the AI to confirm with the user first.
4. The AI must read back the answer, get the user's "yes", then call `gather_submit` again with `confirmed_by_user: "true"`.

#### Per-Question Instructions and Functions

Each question can have additional instructions and specific functions made available:

<!-- snippet: no-compile ruby method-chain continuation fragment (leading `.method`) -->
```ruby
.add_gather_question(
  key:       'home_airport',
  question:  'What is your home airport or nearest major city for departure?',
  type:      'string',
  confirm:   true,
  prompt:    'Use the resolve_airport function to validate the airport code ' \
             'before submitting. If the airport is ambiguous, clarify with the user.',
  functions: %w[resolve_airport]
)
```

The `resolve_airport` function must already be registered on the agent. The `functions` array activates those functions for this question only, alongside `gather_submit`. When the next question begins, they're deactivated again.

#### Output Storage

Answers are stored in `global_data`, which is available in prompt variable expansion via `${key}`:

```ruby
# Store under a namespace
.set_gather_info(output_key: 'profile')
# Results in: global_data.profile.first_name, global_data.profile.last_name, etc.
# Accessible in prompts as: ${profile}

# Store at top level (no output_key)
.set_gather_info
# Results in: global_data.first_name, global_data.last_name, etc.
```

After gathering, `global_data` is refreshed so subsequent step prompts can reference the collected values:

```ruby
ctx.add_step('plan_trip')
   .set_text(
     "The caller's travel profile is: ${profile}. " \
     'Use their name, budget, and preferences to suggest destinations.'
   )
```

#### Auto-Advancing After Gather

With `completion_action`, the step automatically advances when the last question is answered. You can advance to the next sequential step or jump to a specific named step:

```ruby
# Advance to the next sequential step
ctx.add_step('collect_profile')
   .set_text("Collect the caller's profile.")
   .set_gather_info(
     output_key:        'profile',
     completion_action: 'next_step',
     prompt:            'Welcome the caller. You need to collect a few details.'
   )
   .add_gather_question(key: 'name',  question: 'What is your name?')
   .add_gather_question(key: 'email', question: 'What is your email?')

# This step runs immediately after the last question is answered
ctx.add_step('process')
   .set_text("You have the caller's profile in ${profile}. Help them with their request.")
```

You can also jump to a specific step by name:

```ruby
ctx.add_step('collect_info')
   .set_text('Collect caller info.')
   .set_gather_info(
     output_key:        'info',
     completion_action: 'review' # Jump directly to "review" step
   )
   .add_gather_question(key: 'name',  question: 'What is your name?')
   .add_gather_question(key: 'issue', question: 'What is your issue?')

ctx.add_step('other_step')
   .set_text('This step is skipped when coming from collect_info.')

ctx.add_step('review')
   .set_text('Review the collected info in ${info} and help the caller.')
```

> **Note**: The target step is validated at build time. Using `"next_step"` on the last step in a context, or naming a step that doesn't exist, will raise an `ArgumentError`.

#### Combining Gather with Normal Step Mode

Without `completion_action` (or when set to None), the step returns to normal mode after all questions are answered:

```ruby
ctx.add_step('intake')
   .set_text(
     "Review the caller's information in ${intake_data}. " \
     'Confirm everything looks correct, then proceed to scheduling.'
   )
   .set_gather_info(output_key: 'intake_data')
   .add_gather_question(key: 'name',   question: 'What is your name?')
   .add_gather_question(key: 'dob',    question: 'What is your date of birth?')
   .add_gather_question(key: 'reason', question: 'What is the reason for your visit?')
   .set_valid_steps(%w[schedule])
```

Flow:
1. Gather mode: Questions are asked one at a time
2. All questions answered -> step switches to normal mode
3. Step text is injected with `valid_steps` and `step_criteria` restored
4. The AI follows the normal step instructions using the gathered data
5. Navigation to `schedule` becomes available

#### Gather Info API Reference

**`set_gather_info()` Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `output_key` | String | `nil` | Key in global_data to store answers under. If `nil`, answers stored at top level. |
| `completion_action` | String | `nil` | Where to go when all questions are answered: `"next_step"` to advance sequentially, or a specific step name (e.g. `"process_results"`) to jump to that step. If `nil`, returns to normal step mode. The target is validated — `"next_step"` requires a following step, and named steps must exist in the context. |
| `prompt` | String | `nil` | Preamble text injected once as a persistent message when entering the gather step. |

**`add_gather_question()` Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `key` | String | required | Key name for storing the answer in global_data |
| `question` | String | required | The question text presented to the AI |
| `type` | String | `"string"` | JSON schema type: `"string"`, `"integer"`, `"number"`, `"boolean"` |
| `confirm` | Boolean | `false` | If `true`, AI must confirm answer with user before submitting |
| `prompt` | String | `nil` | Additional instruction text for this question |
| `functions` | Array | `nil` | Function names to make visible for this question only |

## Real-World Examples

### Example 1: Technical Support Troubleshooting

```ruby
agent = SignalWire::AgentBase.new(name: 'Tech Support', route: '/tech-support')

# Add diagnostic tools
agent.add_skill('web_search', { 'api_key' => 'key', 'search_engine_id' => 'id' })
agent.add_skill('datetime')

contexts = agent.define_contexts

# Initial triage
triage = contexts.add_context('triage')
triage.add_step('problem_identification')
      .add_section('Current Task', 'Identify the type of technical issue')
      .add_bullets('Information to Gather', [
        'Description of the specific problem',
        'When did the issue start occurring?',
        'What steps has the customer already tried?',
        'Rate the severity level (critical/high/medium/low)'
      ])
      .set_step_criteria('Issue type and severity determined')
      .set_valid_contexts(%w[hardware software network])

# Hardware troubleshooting
hardware = contexts.add_context('hardware')
hardware.add_step('hardware_diagnosis')
        .add_section('Current Task', 'Guide user through hardware diagnostics')
        .add_section('Available Tools', 'Use web search to find hardware specifications and troubleshooting guides')
        .set_functions(%w[web_search]) # Can search for hardware info
        .set_step_criteria('Hardware issue diagnosed')
        .set_valid_steps(%w[hardware_solution])

hardware.add_step('hardware_solution')
        .set_text("Based on the diagnosis, here's how to resolve the hardware issue...")
        .set_step_criteria('Solution provided and tested')
        .set_valid_contexts(%w[triage]) # Can start over if needed

# Software troubleshooting
software = contexts.add_context('software')
software.add_step('software_diagnosis')
        .add_section('Current Task', 'Diagnose software-related issues')
        .add_section('Available Tools', 'Use web search for software updates and datetime to check for recent changes')
        .set_functions(%w[web_search datetime]) # Can check for updates
        .set_step_criteria('Software issue identified')
        .set_valid_steps(%w[software_fix escalation])

software.add_step('software_fix')
        .set_text("Let's try these software troubleshooting steps...")
        .set_step_criteria('Fix attempted and result confirmed')
        .set_valid_steps(%w[escalation resolution])

software.add_step('escalation')
        .set_text("I'll escalate this to our specialist team.")
        .set_functions('none') # No tools needed for escalation
        .set_step_criteria('Escalation ticket created')

software.add_step('resolution')
        .set_text('Great! The issue has been resolved.')
        .set_step_criteria('Customer confirms resolution')
        .set_valid_contexts(%w[triage])

# Network troubleshooting
network = contexts.add_context('network')
network.add_step('network_diagnosis')
       .add_section('Current Task', 'Diagnose network and connectivity issues')
       .add_section('Available Tools', 'Use web search to check service status and datetime for outage windows')
       .set_functions(%w[web_search datetime]) # Check service status
       .set_step_criteria('Network issue diagnosed')
       .set_valid_steps(%w[network_fix])

network.add_step('network_fix')
       .set_text("Let's resolve your connectivity issue with these steps...")
       .set_step_criteria('Network connectivity restored')
       .set_valid_contexts(%w[triage])

agent.run
```

### Example 2: Multi-Step Application Process

```ruby
agent = SignalWire::AgentBase.new(name: 'Loan Application', route: '/loan-app')

# Add verification tools
agent.add_skill('datetime') # For date validation

contexts = agent.define_contexts

# Single workflow context
application = contexts.add_context('default')

# Step 1: Introduction and eligibility
application.add_step('introduction')
           .add_section('Current Task', 'Guide customers through the loan application process')
           .add_bullets('Information to Provide', [
             'Explain the process clearly',
             'Outline what information will be needed',
             'Set expectations for timeline and next steps'
           ])
           .set_step_criteria('Customer understands process and wants to continue')
           .set_valid_steps(%w[personal_info])

# Step 2: Personal information
application.add_step('personal_info')
           .add_section('Instructions', 'Collect personal information')
           .add_bullets('Required Details', [
             'Full legal name',
             'Date of birth',
             'Social Security Number',
             'Phone number and email'
           ])
           .set_functions(%w[datetime]) # Can validate dates
           .set_step_criteria('All personal information collected and verified')
           .set_valid_steps(%w[employment_info personal_info]) # Can review/edit

# Step 3: Employment information
application.add_step('employment_info')
           .set_text('Now I need information about your employment and income.')
           .set_step_criteria('Employment and income information complete')
           .set_valid_steps(%w[financial_info personal_info]) # Can go back

# Step 4: Financial information
application.add_step('financial_info')
           .set_text("Let's review your financial situation including assets and debts.")
           .set_step_criteria('Financial information complete')
           .set_valid_steps(%w[review employment_info]) # Can go back

# Step 5: Review all information
application.add_step('review')
           .add_section('Instructions', 'Review all collected information')
           .add_bullets('Items to Review', [
             'Confirm personal details',
             'Verify employment information',
             'Review financial data',
             'Ensure accuracy before submission'
           ])
           .set_step_criteria('Customer has reviewed and confirmed all information')
           .set_valid_steps(%w[submit personal_info employment_info financial_info])

# Step 6: Submission
application.add_step('submit')
           .set_text("Thank you! Your loan application has been submitted successfully. You'll receive a decision within 2-3 business days.")
           .set_functions('none') # No tools needed for final message
           .set_step_criteria('Application submitted and confirmation provided')
# No valid_steps = end of process

agent.run
```

### Example 3: E-commerce Customer Service

```ruby
agent = SignalWire::AgentBase.new(name: 'E-commerce Support', route: '/ecommerce')

# Add tools for order management
agent.add_skill('web_search', { 'api_key' => 'key', 'search_engine_id' => 'id' })
agent.add_skill('datetime')

contexts = agent.define_contexts

# Main service menu
main = contexts.add_context('main')
main.add_step('service_menu')
    .add_section('Current Task', 'Help customers with their orders and questions')
    .add_bullets('Service Areas Available', [
      'Order status, modifications, and tracking',
      'Returns and refunds',
      'Product information and specifications',
      'Account-related questions'
    ])
    .set_step_criteria("Customer's need has been identified")
    .set_valid_contexts(%w[orders returns products account])

# Order management context
orders = contexts.add_context('orders')
orders.add_step('order_assistance')
      .add_section('Current Task', 'Help with order status, modifications, and tracking')
      .add_section('Available Tools', 'Use datetime to check delivery dates and processing times')
      .set_functions(%w[datetime]) # Can check delivery dates
      .set_step_criteria('Order issue resolved or escalated')
      .set_valid_contexts(%w[main])

# Returns and refunds context
returns = contexts.add_context('returns')
returns.add_step('return_process')
       .add_section('Current Task', 'Guide customers through return process')
       .add_bullets('Return Process Steps', [
         'Verify return eligibility',
         'Explain return policy',
         'Provide return instructions',
         'Process refund if applicable'
       ])
       .set_functions('none') # Sensitive financial operations
       .set_step_criteria('Return request processed')
       .set_valid_contexts(%w[main])

# Product information context
products = contexts.add_context('products')
products.add_step('product_help')
        .add_section('Current Task', 'Help customers with product questions')
        .add_section('Available Tools', 'Use web search to find detailed product information and specifications')
        .set_functions(%w[web_search]) # Can search for product info
        .set_step_criteria('Product question answered')
        .set_valid_contexts(%w[main])

# Account management context
account = contexts.add_context('account')
account.add_step('account_help')
       .set_text('I can help with account-related questions. Please verify your identity first.')
       .set_functions('none') # Security-sensitive context
       .set_step_criteria('Account issue resolved')
       .set_valid_contexts(%w[main])

agent.run
```

## Best Practices

### 1. Clear Step Naming

Use descriptive step names that indicate purpose:

```ruby
# Good
.add_step('collect_shipping_address')
.add_step('verify_payment_method')
.add_step('confirm_order_details')

# Avoid
.add_step('step1')
.add_step('next')
.add_step('continue')
```

### 2. Meaningful Completion Criteria

Define clear, testable completion criteria:

```ruby
# Good - specific and measurable
.set_step_criteria('User has provided valid email address and confirmed subscription preferences')
.set_step_criteria('All required fields completed and payment method verified')

# Avoid - vague or subjective
.set_step_criteria('User is ready')
.set_step_criteria('Everything is good')
```

### 3. Logical Navigation Flow

Design intuitive navigation that matches user expectations:

```ruby
# Allow users to go back and review
.set_valid_steps(%w[review_info edit_details confirm_submission])

# Provide escape routes
.set_valid_contexts(%w[main_menu help])

# Consider dead ends carefully
.set_valid_steps([]) # Only if this is truly the end
```

### 4. Progressive Function Access

Restrict functions based on security and context needs:

```ruby
# Public areas - limited functions
public_step.functions = %w[datetime web_search]

# Authenticated areas - more functions allowed
auth_step.functions = %w[datetime web_search user_profile]

# Sensitive operations - minimal functions
billing_step.functions = 'none'
```

### 5. Context Organization

Organize contexts by functional area or user journey:

```ruby
# By functional area
contexts = %w[triage technical_support billing account_management]

# By user journey stage
contexts = %w[onboarding verification configuration completion]

# By security level
contexts = %w[public authenticated admin]
```

### 6. Error Handling and Recovery

Provide recovery paths for common issues:

```ruby
# Allow users to retry failed steps
.set_valid_steps(%w[retry_payment choose_different_method contact_support])

# Provide help context access
.set_valid_contexts(%w[help main])

# Include validation steps
verification_ctx.add_step('validation')
                .set_step_criteria('Data validation passed')
                .set_valid_steps(%w[proceed edit_data])
```

### 7. Content Strategy

Choose the right content approach for each step:

```ruby
# Use set_text for simple, direct instructions
step.set_text('Please provide your email address')

# Use POM sections for complex, structured content
step.add_section('Role', 'You are a technical specialist')
    .add_section('Context', 'Customer is experiencing network issues')
    .add_section('Instructions', 'Follow diagnostic protocol')
    .add_bullets('Steps', ['Check connectivity', 'Test speed', 'Verify settings'])
```

## Troubleshooting

### Common Issues

#### 1. "Single context must be named 'default'"

**Error**: When using a single context with a name other than "default"

```ruby
# Wrong
context = contexts.add_context('main') # Error!

# Correct
context = contexts.add_context('default')
```

#### 2. "Cannot mix set_text with add_section"

**Error**: Using both direct text and POM sections in the same step

```ruby
# Wrong
step.set_text('Welcome!')
    .add_section('Role', 'Assistant') # Error!

# Correct - choose one approach
step.set_text("Welcome! I'm your assistant.")
# OR
step.add_section('Role', 'Assistant')
    .add_section('Message', 'Welcome!')
```

#### 3. Navigation Issues

**Problem**: Users getting stuck or unable to navigate

```ruby
# Check your navigation rules
step.valid_steps = []    # Dead end - is this intended?
step.valid_contexts = [] # Trapped in context - is this intended?

# Add appropriate navigation
step.valid_steps = %w[next_step previous_step]
step.valid_contexts = %w[main help]
```

#### 4. Function Access Problems

**Problem**: Functions not available when expected

```ruby
# Check function restrictions
step.functions = 'none'        # All functions blocked
step.functions = %w[datetime]  # Only datetime allowed

# Verify function names match your agent's functions
agent.add_skill('web_search')   # Function name is "web_search"
step.functions = %w[web_search] # Must match exactly
```

### Debugging Tips

#### 1. Trace Navigation Flow

Add logging to understand flow:

```ruby
def create_step_with_logging(context, name)
  step = context.add_step(name)
  puts "Created step: #{name}"
  step
end
```

#### 2. Validate Navigation Rules

Check that all referenced steps/contexts exist:

```ruby
# Ensure referenced steps exist
.set_valid_steps(%w[review edit]) # Both "review" and "edit" steps must exist

# Ensure referenced contexts exist
.set_valid_contexts(%w[main help]) # Both "main" and "help" contexts must exist
```

#### 3. Test Function Restrictions

Verify functions are properly restricted:

```ruby
# Test with all functions
# step  # No functions assignment

# Test with restrictions
step.functions = %w[datetime]

# Test with no functions
step.functions = 'none'
```

## Migration from POM

### Converting Traditional Prompts

**Before (Traditional POM):**
```ruby
agent = SignalWire::AgentBase.new(name: 'assistant', route: '/assistant')

agent.prompt_add_section('Role', 'You are a helpful assistant')
agent.prompt_add_section('Instructions', 'Help users with questions')
agent.prompt_add_section('Guidelines', bullets: [
  'Be friendly',
  'Ask clarifying questions',
  'Provide accurate information'
])
```

**After (Contexts and Steps):**
```ruby
agent = SignalWire::AgentBase.new(name: 'assistant', route: '/assistant')

contexts = agent.define_contexts
main = contexts.add_context('default')

# Note: the Ruby Step adds bullets via a separate `add_bullets(title, bullets)`
# call rather than a `bullets:` option on `add_section`.
main.add_step('assistance')
    .add_section('Role', 'You are a helpful assistant')
    .add_section('Instructions', 'Help users with questions')
    .add_bullets('Guidelines', [
      'Be friendly',
      'Ask clarifying questions',
      'Provide accurate information'
    ])
    .set_step_criteria("User's question has been answered")
```

### Hybrid Approach

You can use both traditional prompts and contexts in the same agent:

```ruby
agent = SignalWire::AgentBase.new(name: 'hybrid', route: '/hybrid')

# Traditional prompt sections (from skills, global settings, etc.)
# These will coexist with contexts

# Define contexts for structured workflows
contexts = agent.define_contexts
workflow = contexts.add_context('default')

workflow.add_step('structured_process')
        .set_text('Following the structured workflow...')
        .set_step_criteria('Workflow complete')
```

### Migration Strategy

1. **Start Simple**: Convert one workflow at a time
2. **Preserve Existing**: Keep traditional prompts for simple interactions
3. **Add Structure**: Use contexts for complex, multi-step processes
4. **Test Thoroughly**: Verify navigation and function access work as expected
5. **Iterate**: Refine step criteria and navigation based on testing

---

## Conclusion

The Contexts and Steps system provides structured workflow control for building sophisticated AI agents. By combining structured navigation, function restrictions, and clear completion criteria, you can create predictable, user-friendly agent experiences that guide users through complex processes while maintaining security and control.

Start with simple single-context workflows and gradually build more complex multi-context systems as your requirements grow. The system is designed to be flexible and scalable, supporting both simple linear workflows and complex branching conversation trees.

### Dynamic Context Switching

To switch contexts dynamically during a conversation, return a `FunctionResult` with the `swml_change_context` method from a tool handler:

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'multi-context', route: '/multi')

# Define contexts using the ContextBuilder pattern
contexts = agent.define_contexts

# Sales context
sales = contexts.add_context('sales')
sales.add_section('Role', 'You are a helpful sales representative.')
sales.add_step('greeting').set_text('Welcome customers and understand their needs.')

# Support context
support = contexts.add_context('support')
support.add_section('Role', 'You are a technical support specialist.')
support.add_step('diagnose').set_text('Help diagnose and resolve technical issues.')

agent.define_tool(
  name:        'transfer_to_support',
  description: 'Transfer the customer to technical support',
  parameters:  {}
) do |_args, _raw_data|
  # Use swml_change_context to switch contexts
  SignalWire::Swaig::FunctionResult.new('Transferring you to technical support...')
                                   .swml_change_context('support')
end

agent.define_tool(
  name:        'transfer_to_sales',
  description: 'Transfer the customer to sales',
  parameters:  {}
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new('Transferring you to sales...')
                                   .swml_change_context('sales')
end
```

For a complete example of multi-context agents with different personas, see `examples/contexts_demo.rb`.

---

### Example 4: Travel Profile Agent (Gather Info Mode)

Collects a travel profile with typed questions and confirmation, then recommends destinations:

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'Travel Agent', route: '/travel')

agent.prompt_add_section('Role', 'You are a friendly travel booking assistant.')

contexts = agent.define_contexts
ctx = contexts.add_context('default')

# Step 1: Collect profile (gather mode, auto-advance)
ctx.add_step('collect_profile')
   .set_text("Collect the caller's travel profile.")
   .set_gather_info(
     output_key:        'profile',
     completion_action: 'next_step',
     prompt:            'Welcome the caller and introduce yourself as a travel ' \
                        'booking assistant. You need to collect a few details ' \
                        'to build their travel profile. Be warm and conversational.'
   )
   .add_gather_question(key: 'first_name', question: 'What is your first name?')
   .add_gather_question(key: 'last_name', question: 'What is your last name?', confirm: true)
   .add_gather_question(key: 'party_size', question: 'How many people are traveling?', type: 'integer')
   .add_gather_question(key: 'budget_per_person', question: 'What is your budget per person?', type: 'number')
   .add_gather_question(key: 'has_passport', question: 'Do you have a valid passport?', type: 'boolean')
   .add_gather_question(key: 'home_airport', question: 'What is your home airport?', confirm: true)

# Step 2: Recommend destinations (normal mode)
ctx.add_step('plan_trip')
   .set_text(
     "You now have the caller's travel profile in ${profile}. " \
     'Use their name, party size, budget, passport status, and ' \
     'home airport to suggest three vacation destinations. ' \
     "If they don't have a passport, only suggest domestic destinations."
   )

agent.add_language('English', 'en-US', 'rime.spore')
```

### Example 5: Support Ticket Agent (Gather + Triage)

Gathers issue details, then routes to the right team using normal mode navigation:

```ruby
require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'Support Agent', route: '/support')

agent.prompt_add_section('Role', 'You are a technical support agent.')

contexts = agent.define_contexts
ctx = contexts.add_context('default')

# Collect ticket info, then return to normal mode for triage
ctx.add_step('intake')
   .set_text(
     "You have the caller's issue details in ${ticket}. " \
     'Based on the category and description, route them to ' \
     'the appropriate team.'
   )
   .set_gather_info(
     output_key: 'ticket',
     prompt:     'Thank the caller for contacting support. ' \
                 'You need to collect some details about their issue.'
   )
   .add_gather_question(key: 'name', question: 'What is your name?')
   .add_gather_question(key: 'account_id', question: 'What is your account ID?', confirm: true)
   .add_gather_question(key: 'category', question: 'Is this about billing, a technical issue, or something else?')
   .add_gather_question(key: 'description', question: 'Please describe the issue in detail.')
   .set_valid_steps(%w[billing_support tech_support general_support])

ctx.add_step('billing_support')
   .set_text('Help the caller with their billing issue. Details: ${ticket}.')

ctx.add_step('tech_support')
   .set_text('Help the caller with their technical issue. Details: ${ticket}.')
   .set_functions(%w[run_diagnostics check_service_status])

ctx.add_step('general_support')
   .set_text('Help the caller with their general inquiry. Details: ${ticket}.')

agent.add_language('English', 'en-US', 'rime.spore')
```

Note: This example uses gather **without** `completion_action`. After all questions are answered, the step returns to normal mode with `valid_steps` restored. The AI uses the gathered data to decide which support step to route to.

## Related Documentation

- **[API Reference](api_reference.md)** - Complete AgentBase class reference
- **[SWAIG Reference](swaig_reference.md)** - All available result methods including `swml_change_context()` and `swml_change_step()`
- **[Agent Guide](agent_guide.md)** - General agent development guide
- **[DataMap Guide](datamap_guide.md)** - Serverless function integration

### Example Files

- `examples/contexts_demo.rb` - Multi-context insurance claims agent with steps and tools
- `examples/gather_info_demo.rb` - Structured data collection using `set_gather_info` and `add_gather_question`
- `examples/survey_agent_example.rb` - Survey workflow with steps
- `examples/info_gatherer_example.rb` - Information gathering workflow
- `examples/step_function_inheritance_demo.rb` - Per-step function whitelist inheritance behavior