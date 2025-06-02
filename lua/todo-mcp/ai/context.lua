-- AI Context Module
-- Provides intelligent context detection for todos with lazy language loading
-- Language-specific features are only loaded when working with files of that type
local M = {}

-- Language detectors registry - loaded on demand
-- This prevents loading language-specific code until actually needed
M.language_detectors = {
  py = nil,
  js = nil,
  ts = nil,
  jsx = nil,
  tsx = nil,
  rs = nil,
  go = nil,
  lua = nil
}

-- Map file extensions to language types
M.get_language_from_extension = function(ext)
  local extension_map = {
    py = "python",
    js = "javascript",
    jsx = "javascript",
    ts = "typescript",
    tsx = "typescript",
    lua = "lua",
    rs = "rust",
    go = "go",
    c = "c",
    cpp = "cpp",
    cc = "cpp",
    cxx = "cpp",
    h = "c",
    hpp = "cpp",
    java = "java",
    rb = "ruby",
    php = "php",
    cs = "csharp",
    swift = "swift",
    kt = "kotlin",
    scala = "scala",
    r = "r",
    m = "objective-c",
    mm = "objective-c++"
  }
  
  return extension_map[ext] or "unknown"
end

-- Enhanced context detection with AI-like intelligence
M.detect_enhanced_context = function(filepath, line_content, surrounding_lines)
  local context = {
    file_analysis = M.analyze_file_structure(filepath),
    code_analysis = M.analyze_code_context(line_content, surrounding_lines),
    project_analysis = M.analyze_project_context(filepath),
    semantic_analysis = M.analyze_semantic_context(line_content, surrounding_lines)
  }
  
  -- Combine all analyses into unified context
  return M.synthesize_context(context)
end

-- Analyze file structure and patterns
M.analyze_file_structure = function(filepath)
  local analysis = {
    file_type = vim.fn.fnamemodify(filepath, ":e"),
    directory_depth = #vim.split(filepath, "/") - 1,
    naming_patterns = {},
    architectural_layer = nil
  }
  
  local filename = vim.fn.fnamemodify(filepath, ":t:r")
  local dir_path = vim.fn.fnamemodify(filepath, ":h")
  local dirs = vim.split(dir_path, "/")
  
  -- Detect naming patterns
  if filename:match("%.test%.") or filename:match("%.spec%.") then
    analysis.naming_patterns.test_file = true
  end
  
  if filename:match("%.config%.") or filename:match("%.setup%.") then
    analysis.naming_patterns.config_file = true
  end
  
  if filename:match("index$") or filename:match("main$") then
    analysis.naming_patterns.entry_point = true
  end
  
  -- Detect architectural layers
  for _, dir in ipairs(dirs) do
    local layer_map = {
      -- Frontend layers
      components = "presentation",
      pages = "presentation", 
      views = "presentation",
      hooks = "presentation",
      
      -- Business logic
      services = "business",
      utils = "business",
      helpers = "business",
      lib = "business",
      
      -- Data layer
      models = "data",
      api = "data",
      database = "data",
      db = "data",
      
      -- Infrastructure
      config = "infrastructure",
      deploy = "infrastructure",
      docker = "infrastructure",
      scripts = "infrastructure"
    }
    
    if layer_map[dir] then
      analysis.architectural_layer = layer_map[dir]
      break
    end
  end
  
  return analysis
end

-- Analyze code context around the TODO
M.analyze_code_context = function(line_content, surrounding_lines)
  surrounding_lines = surrounding_lines or {}
  
  local analysis = {
    code_patterns = {},
    complexity_indicators = {},
    scope_context = {},
    dependencies = {}
  }
  
  -- Analyze the TODO line itself
  local todo_text = line_content:match("TODO:?%s*(.+)") or 
                   line_content:match("FIXME:?%s*(.+)") or
                   line_content:match("HACK:?%s*(.+)") or ""
  
  -- Detect code patterns in surrounding lines
  local all_lines = vim.list_extend({line_content}, surrounding_lines)
  
  for _, line in ipairs(all_lines) do
    -- Function definitions
    if line:match("function%s+") or line:match("def%s+") or line:match("const%s+%w+%s*=") then
      analysis.code_patterns.function_definition = true
    end
    
    -- Class definitions
    if line:match("class%s+") or line:match("interface%s+") or line:match("type%s+") then
      analysis.code_patterns.type_definition = true
    end
    
    -- Error handling
    if line:match("try%s*{") or line:match("catch") or line:match("throw") or line:match("error") then
      analysis.code_patterns.error_handling = true
    end
    
    -- Performance concerns
    if line:match("setTimeout") or line:match("setInterval") or line:match("async") or line:match("await") then
      analysis.code_patterns.async_code = true
    end
    
    -- Database operations
    if line:match("SELECT") or line:match("INSERT") or line:match("UPDATE") or line:match("query") then
      analysis.code_patterns.database_operation = true
    end
    
    -- Network requests
    if line:match("fetch") or line:match("axios") or line:match("http") or line:match("request") then
      analysis.code_patterns.network_request = true
    end
    
    -- Security patterns
    if line:match("auth") or line:match("token") or line:match("password") or line:match("secret") then
      analysis.code_patterns.security_related = true
    end
  end
  
  -- Analyze complexity indicators
  local complexity_score = 0
  
  for _, line in ipairs(all_lines) do
    -- Cyclomatic complexity indicators
    if line:match("if%s*%(") then complexity_score = complexity_score + 1 end
    if line:match("for%s*%(") then complexity_score = complexity_score + 1 end
    if line:match("while%s*%(") then complexity_score = complexity_score + 1 end
    if line:match("switch%s*%(") then complexity_score = complexity_score + 2 end
    if line:match("catch%s*%(") then complexity_score = complexity_score + 1 end
  end
  
  analysis.complexity_indicators.cyclomatic_score = complexity_score
  analysis.complexity_indicators.complexity_level = 
    complexity_score <= 2 and "low" or
    complexity_score <= 5 and "medium" or "high"
  
  return analysis
end

-- Analyze project-wide context
M.analyze_project_context = function(filepath)
  local analysis = {
    project_type = nil,
    framework_detected = {},
    build_system = nil,
    git_context = {}
  }
  
  -- Try to detect project root and analyze project files
  local project_root = M.find_project_root(filepath)
  if not project_root then
    return analysis
  end
  
  -- First detect language from file extension
  local ext = vim.fn.fnamemodify(filepath, ":e")
  local lang = M.get_language_from_extension(ext)
  
  -- Only check project files relevant to the detected language
  if lang == "javascript" or lang == "typescript" then
    local package_json = project_root .. "/package.json"
    if vim.fn.filereadable(package_json) == 1 then
      analysis.project_type = lang
      analysis.framework_detected = M.detect_js_frameworks(package_json)
    end
  elseif lang == "python" then
    -- Only load Python detection if we're in a Python file
    local requirements_txt = project_root .. "/requirements.txt"
    if vim.fn.filereadable(requirements_txt) == 1 then
      analysis.project_type = "python"
      analysis.framework_detected = M.detect_python_frameworks_lazy(requirements_txt)
    end
  elseif lang == "rust" then
    local cargo_toml = project_root .. "/Cargo.toml"
    if vim.fn.filereadable(cargo_toml) == 1 then
      analysis.project_type = "rust"
    end
  elseif lang == "go" then
    local go_mod = project_root .. "/go.mod"
    if vim.fn.filereadable(go_mod) == 1 then
      analysis.project_type = "go"
    end
  else
    analysis.project_type = lang
  end
  
  -- Git context
  local git_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
  if git_branch ~= "" then
    analysis.git_context.branch = git_branch
    analysis.git_context.branch_type = M.classify_branch_type(git_branch)
  end
  
  return analysis
end

-- Analyze semantic meaning of TODO text
M.analyze_semantic_context = function(line_content, surrounding_lines)
  local analysis = {
    intent_classification = {},
    urgency_indicators = {},
    effort_estimation = {},
    domain_classification = {}
  }
  
  local todo_text = line_content:match("TODO:?%s*(.+)") or 
                   line_content:match("FIXME:?%s*(.+)") or
                   line_content:match("HACK:?%s*(.+)") or ""
  
  todo_text = todo_text:lower()
  
  -- Intent classification using keyword analysis
  local intent_keywords = {
    refactor = {"refactor", "clean", "simplify", "reorganize", "restructure"},
    optimize = {"optimize", "performance", "speed", "faster", "slow", "bottleneck"},
    fix = {"fix", "bug", "error", "broken", "issue", "problem"},
    implement = {"implement", "add", "create", "build", "develop"},
    test = {"test", "testing", "spec", "coverage", "unit test"},
    document = {"document", "docs", "comment", "explain", "readme"},
    security = {"security", "auth", "permission", "validate", "sanitize"},
    ui = {"ui", "ux", "design", "layout", "style", "css"},
    api = {"api", "endpoint", "request", "response", "service"}
  }
  
  for intent, keywords in pairs(intent_keywords) do
    for _, keyword in ipairs(keywords) do
      if todo_text:find(keyword) then
        analysis.intent_classification[intent] = true
        break
      end
    end
  end
  
  -- Urgency indicators
  local urgency_keywords = {
    high = {"urgent", "critical", "important", "asap", "immediately", "broken", "failing"},
    medium = {"should", "need", "required", "soon"},
    low = {"maybe", "consider", "could", "nice to have", "eventually"}
  }
  
  for level, keywords in pairs(urgency_keywords) do
    for _, keyword in ipairs(keywords) do
      if todo_text:find(keyword) then
        analysis.urgency_indicators[level] = true
        break
      end
    end
  end
  
  -- Effort estimation based on complexity words
  local effort_keywords = {
    small = {"simple", "quick", "easy", "minor", "trivial"},
    medium = {"refactor", "update", "modify", "change"},
    large = {"rewrite", "major", "complex", "architecture", "redesign", "migrate"}
  }
  
  for size, keywords in pairs(effort_keywords) do
    for _, keyword in ipairs(keywords) do
      if todo_text:find(keyword) then
        analysis.effort_estimation[size] = true
        break
      end
    end
  end
  
  return analysis
end

-- Synthesize all context analyses into unified context
M.synthesize_context = function(context_data)
  local unified = {
    -- Basic file context
    file_type = context_data.file_analysis.file_type,
    architectural_layer = context_data.file_analysis.architectural_layer,
    
    -- Smart tags based on analysis
    smart_tags = {},
    
    -- AI-generated priority
    ai_priority = "medium",
    
    -- Effort estimation
    estimated_effort = "medium",
    
    -- Suggested labels/categories
    suggested_labels = {},
    
    -- Context confidence score
    confidence_score = 0
  }
  
  -- Generate smart tags
  if context_data.file_analysis.naming_patterns.test_file then
    table.insert(unified.smart_tags, "testing")
  end
  
  if context_data.code_analysis.code_patterns.error_handling then
    table.insert(unified.smart_tags, "error-handling")
  end
  
  if context_data.code_analysis.code_patterns.security_related then
    table.insert(unified.smart_tags, "security")
  end
  
  if context_data.code_analysis.code_patterns.performance_related then
    table.insert(unified.smart_tags, "performance")
  end
  
  -- Determine AI priority
  local priority_score = 0
  
  -- Urgency indicators
  if context_data.semantic_analysis.urgency_indicators.high then
    priority_score = priority_score + 3
  elseif context_data.semantic_analysis.urgency_indicators.medium then
    priority_score = priority_score + 2
  elseif context_data.semantic_analysis.urgency_indicators.low then
    priority_score = priority_score + 1
  end
  
  -- Code complexity
  if context_data.code_analysis.complexity_indicators.complexity_level == "high" then
    priority_score = priority_score + 2
  elseif context_data.code_analysis.complexity_indicators.complexity_level == "medium" then
    priority_score = priority_score + 1
  end
  
  -- Intent-based priority
  if context_data.semantic_analysis.intent_classification.fix then
    priority_score = priority_score + 2
  elseif context_data.semantic_analysis.intent_classification.security then
    priority_score = priority_score + 3
  end
  
  unified.ai_priority = 
    priority_score >= 5 and "high" or
    priority_score >= 3 and "medium" or "low"
  
  -- Effort estimation
  local effort_score = 0
  
  if context_data.semantic_analysis.effort_estimation.large then
    effort_score = 3
  elseif context_data.semantic_analysis.effort_estimation.medium then
    effort_score = 2
  elseif context_data.semantic_analysis.effort_estimation.small then
    effort_score = 1
  end
  
  -- Adjust based on complexity
  if context_data.code_analysis.complexity_indicators.complexity_level == "high" then
    effort_score = effort_score + 1
  end
  
  unified.estimated_effort =
    effort_score >= 3 and "large" or
    effort_score >= 2 and "medium" or "small"
  
  -- Generate suggested labels
  for intent, _ in pairs(context_data.semantic_analysis.intent_classification) do
    table.insert(unified.suggested_labels, intent)
  end
  
  if context_data.project_analysis.project_type then
    table.insert(unified.suggested_labels, context_data.project_analysis.project_type)
  end
  
  if context_data.file_analysis.architectural_layer then
    table.insert(unified.suggested_labels, context_data.file_analysis.architectural_layer)
  end
  
  -- Calculate confidence score (0-100)
  local confidence = 50 -- Base confidence
  
  if context_data.project_analysis.project_type then
    confidence = confidence + 10
  end
  
  if #unified.smart_tags > 0 then
    confidence = confidence + (#unified.smart_tags * 5)
  end
  
  if context_data.semantic_analysis.intent_classification then
    confidence = confidence + 15
  end
  
  unified.confidence_score = math.min(confidence, 100)
  
  return unified
end

-- Helper functions
M.find_project_root = function(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  
  while dir ~= "/" do
    -- Check for common project root indicators
    local indicators = {
      ".git", "package.json", "requirements.txt", 
      "Cargo.toml", "go.mod", ".project", "pom.xml"
    }
    
    for _, indicator in ipairs(indicators) do
      if vim.fn.isdirectory(dir .. "/" .. indicator) == 1 or
         vim.fn.filereadable(dir .. "/" .. indicator) == 1 then
        return dir
      end
    end
    
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  
  return nil
end

M.detect_js_frameworks = function(package_json)
  local frameworks = {}
  
  -- Read and parse package.json
  local content = vim.fn.readfile(package_json)
  local package_str = table.concat(content, "\n")
  
  -- Simple framework detection
  if package_str:find("react") then
    table.insert(frameworks, "react")
  end
  
  if package_str:find("vue") then
    table.insert(frameworks, "vue")
  end
  
  if package_str:find("angular") then
    table.insert(frameworks, "angular")
  end
  
  if package_str:find("express") then
    table.insert(frameworks, "express")
  end
  
  if package_str:find("next") then
    table.insert(frameworks, "nextjs")
  end
  
  return frameworks
end

-- Lazy load Python framework detection only when needed
M.detect_python_frameworks_lazy = function(requirements_txt)
  -- Only load the actual detection if we haven't already
  if not M._python_framework_detector then
    M._python_framework_detector = function(req_file)
      local frameworks = {}
      local content = vim.fn.readfile(req_file)
      local requirements_str = table.concat(content, "\n"):lower()
      
      if requirements_str:find("django") then
        table.insert(frameworks, "django")
      end
      if requirements_str:find("flask") then
        table.insert(frameworks, "flask")
      end
      if requirements_str:find("fastapi") then
        table.insert(frameworks, "fastapi")
      end
      if requirements_str:find("pytest") then
        table.insert(frameworks, "pytest")
      end
      
      return frameworks
    end
  end
  
  return M._python_framework_detector(requirements_txt)
end

M.classify_branch_type = function(branch_name)
  local branch_types = {
    feature = {"feature/", "feat/", "add/"},
    bugfix = {"fix/", "bug/", "hotfix/"},
    refactor = {"refactor/", "refact/", "clean/"},
    chore = {"chore/", "maint/", "maintenance/"},
    release = {"release/", "rel/", "version/"}
  }
  
  for type_name, patterns in pairs(branch_types) do
    for _, pattern in ipairs(patterns) do
      if branch_name:find("^" .. pattern) then
        return type_name
      end
    end
  end
  
  return "unknown"
end

return M