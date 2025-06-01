local M = {}

-- AI-powered priority and effort estimation
M.estimate_todo_metrics = function(todo_data, context_data)
  local estimation = {
    priority = M.estimate_priority(todo_data, context_data),
    effort = M.estimate_effort(todo_data, context_data),
    complexity = M.estimate_complexity(todo_data, context_data),
    risk = M.estimate_risk(todo_data, context_data),
    dependencies = M.analyze_dependencies(todo_data, context_data),
    timeline = M.estimate_timeline(todo_data, context_data)
  }
  
  -- Add confidence scores for each estimation
  estimation.confidence = {
    priority = M.calculate_priority_confidence(todo_data, context_data),
    effort = M.calculate_effort_confidence(todo_data, context_data),
    overall = M.calculate_overall_confidence(estimation)
  }
  
  return estimation
end

-- Priority estimation using multiple factors
M.estimate_priority = function(todo_data, context_data)
  local factors = {
    urgency = M.analyze_urgency_signals(todo_data.text),
    impact = M.analyze_impact_signals(todo_data.text, context_data),
    business_value = M.analyze_business_value(todo_data.text, context_data),
    technical_debt = M.analyze_technical_debt(todo_data.text, context_data),
    user_impact = M.analyze_user_impact(todo_data.text, context_data)
  }
  
  local priority_score = M.calculate_weighted_priority_score(factors)
  
  return {
    level = M.score_to_priority_level(priority_score),
    score = priority_score,
    factors = factors,
    reasoning = M.generate_priority_reasoning(factors)
  }
end

-- Effort estimation using historical patterns and complexity analysis
M.estimate_effort = function(todo_data, context_data)
  local factors = {
    scope = M.analyze_scope_indicators(todo_data.text),
    complexity = M.analyze_technical_complexity(todo_data.text, context_data),
    dependencies = M.count_likely_dependencies(todo_data.text, context_data),
    uncertainty = M.measure_uncertainty_level(todo_data.text),
    historical_patterns = M.match_historical_patterns(todo_data.text)
  }
  
  local effort_score = M.calculate_effort_score(factors)
  
  return {
    level = M.score_to_effort_level(effort_score),
    story_points = M.score_to_story_points(effort_score),
    hours_estimate = M.score_to_hours(effort_score),
    factors = factors,
    reasoning = M.generate_effort_reasoning(factors)
  }
end

-- Complexity analysis
M.estimate_complexity = function(todo_data, context_data)
  local complexity_factors = {
    algorithmic = M.analyze_algorithmic_complexity(todo_data.text),
    architectural = M.analyze_architectural_complexity(todo_data.text, context_data),
    integration = M.analyze_integration_complexity(todo_data.text, context_data),
    domain = M.analyze_domain_complexity(todo_data.text, context_data)
  }
  
  local complexity_score = M.calculate_complexity_score(complexity_factors)
  
  return {
    level = M.score_to_complexity_level(complexity_score),
    score = complexity_score,
    factors = complexity_factors,
    suggestions = M.generate_complexity_suggestions(complexity_factors)
  }
end

-- Risk assessment
M.estimate_risk = function(todo_data, context_data)
  local risk_factors = {
    security = M.analyze_security_risks(todo_data.text, context_data),
    performance = M.analyze_performance_risks(todo_data.text, context_data),
    stability = M.analyze_stability_risks(todo_data.text, context_data),
    compatibility = M.analyze_compatibility_risks(todo_data.text, context_data),
    data_integrity = M.analyze_data_risks(todo_data.text, context_data)
  }
  
  local risk_score = M.calculate_risk_score(risk_factors)
  
  return {
    level = M.score_to_risk_level(risk_score),
    score = risk_score,
    factors = risk_factors,
    mitigation_suggestions = M.generate_risk_mitigation(risk_factors)
  }
end

-- Implementation of analysis functions
M.analyze_urgency_signals = function(text)
  local urgency_patterns = {
    critical = {"critical", "urgent", "emergency", "asap", "immediately", "now"},
    high = {"important", "soon", "needed", "required", "breaking"},
    medium = {"should", "would be good", "need to"},
    low = {"maybe", "consider", "could", "nice to have", "eventually", "someday"}
  }
  
  text = text:lower()
  local urgency_score = 0
  local matched_signals = {}
  
  for level, patterns in pairs(urgency_patterns) do
    for _, pattern in ipairs(patterns) do
      if text:find(pattern) then
        local level_scores = {critical = 4, high = 3, medium = 2, low = 1}
        urgency_score = math.max(urgency_score, level_scores[level])
        table.insert(matched_signals, {pattern = pattern, level = level})
      end
    end
  end
  
  return {
    score = urgency_score,
    signals = matched_signals,
    level = urgency_score >= 4 and "critical" or
            urgency_score >= 3 and "high" or
            urgency_score >= 2 and "medium" or "low"
  }
end

M.analyze_impact_signals = function(text, context_data)
  local impact_indicators = {
    user_facing = {"user", "customer", "ui", "ux", "interface", "display"},
    performance = {"performance", "speed", "slow", "fast", "optimize", "bottleneck"},
    security = {"security", "auth", "permission", "vulnerability", "exploit"},
    data = {"data", "database", "corruption", "loss", "backup"},
    integration = {"api", "service", "integration", "external", "third party"}
  }
  
  text = text:lower()
  local impact_score = 0
  local impact_areas = {}
  
  for area, patterns in pairs(impact_indicators) do
    for _, pattern in ipairs(patterns) do
      if text:find(pattern) then
        impact_areas[area] = true
        -- Weight different impact areas
        local area_weights = {
          security = 4, data = 4, user_facing = 3, 
          performance = 3, integration = 2
        }
        impact_score = impact_score + (area_weights[area] or 1)
      end
    end
  end
  
  -- Boost score based on architectural layer
  if context_data and context_data.architectural_layer == "presentation" then
    impact_score = impact_score + 1
  end
  
  return {
    score = math.min(impact_score, 10),
    areas = vim.tbl_keys(impact_areas),
    level = impact_score >= 8 and "high" or
            impact_score >= 4 and "medium" or "low"
  }
end

M.analyze_scope_indicators = function(text)
  local scope_patterns = {
    large = {
      "rewrite", "redesign", "refactor entire", "major", "complete", 
      "all", "system", "architecture", "migrate", "rebuild"
    },
    medium = {
      "refactor", "update", "modify", "change", "improve", 
      "enhance", "extend", "add feature"
    },
    small = {
      "fix", "adjust", "tweak", "minor", "simple", 
      "quick", "small", "tiny", "trivial"
    }
  }
  
  text = text:lower()
  local scope_score = 2 -- Default medium
  local matched_patterns = {}
  
  for size, patterns in pairs(scope_patterns) do
    for _, pattern in ipairs(patterns) do
      if text:find(pattern) then
        local size_scores = {large = 5, medium = 3, small = 1}
        scope_score = math.max(scope_score, size_scores[size])
        table.insert(matched_patterns, {pattern = pattern, size = size})
      end
    end
  end
  
  return {
    score = scope_score,
    patterns = matched_patterns,
    level = scope_score >= 5 and "large" or
            scope_score >= 3 and "medium" or "small"
  }
end

M.analyze_technical_complexity = function(text, context_data)
  local complexity_indicators = {
    algorithm = {"algorithm", "optimization", "complexity", "big o", "performance"},
    concurrency = {"async", "thread", "parallel", "concurrent", "race condition"},
    integration = {"api", "service", "external", "third party", "webhook"},
    data_structure = {"tree", "graph", "hash", "index", "query", "search"},
    security = {"encryption", "auth", "token", "certificate", "hash"},
    networking = {"network", "http", "tcp", "websocket", "protocol"}
  }
  
  text = text:lower()
  local complexity_score = 1
  local complexity_areas = {}
  
  for area, patterns in pairs(complexity_indicators) do
    for _, pattern in ipairs(patterns) do
      if text:find(pattern) then
        complexity_areas[area] = true
        complexity_score = complexity_score + 1
      end
    end
  end
  
  -- Context-based complexity boost
  if context_data and context_data.code_analysis then
    local code_complexity = context_data.code_analysis.complexity_indicators
    if code_complexity and code_complexity.complexity_level == "high" then
      complexity_score = complexity_score + 2
    end
  end
  
  return {
    score = math.min(complexity_score, 10),
    areas = vim.tbl_keys(complexity_areas),
    level = complexity_score >= 7 and "high" or
            complexity_score >= 4 and "medium" or "low"
  }
end

-- Scoring and conversion functions
M.calculate_weighted_priority_score = function(factors)
  local weights = {
    urgency = 0.3,
    impact = 0.25,
    business_value = 0.2,
    technical_debt = 0.15,
    user_impact = 0.1
  }
  
  local weighted_score = 0
  for factor, weight in pairs(weights) do
    if factors[factor] and factors[factor].score then
      weighted_score = weighted_score + (factors[factor].score * weight)
    end
  end
  
  return math.min(weighted_score, 10)
end

M.score_to_priority_level = function(score)
  if score >= 7 then return "high"
  elseif score >= 4 then return "medium"
  else return "low" end
end

M.score_to_effort_level = function(score)
  if score >= 8 then return "xl"
  elseif score >= 6 then return "large"
  elseif score >= 4 then return "medium"
  elseif score >= 2 then return "small"
  else return "xs" end
end

M.score_to_story_points = function(score)
  local point_mapping = {
    [1] = 1, [2] = 2, [3] = 3, [4] = 5, 
    [5] = 8, [6] = 13, [7] = 21, [8] = 34
  }
  
  local rounded_score = math.ceil(score)
  return point_mapping[rounded_score] or 1
end

M.score_to_hours = function(score)
  -- Rough hour estimates based on effort score
  local hour_mapping = {
    [1] = {min = 1, max = 2},
    [2] = {min = 2, max = 4}, 
    [3] = {min = 4, max = 8},
    [4] = {min = 8, max = 16},
    [5] = {min = 16, max = 32},
    [6] = {min = 32, max = 64},
    [7] = {min = 64, max = 128},
    [8] = {min = 128, max = 256}
  }
  
  local rounded_score = math.ceil(score)
  return hour_mapping[rounded_score] or {min = 1, max = 2}
end

-- Reasoning generation
M.generate_priority_reasoning = function(factors)
  local reasons = {}
  
  if factors.urgency and factors.urgency.level == "critical" then
    table.insert(reasons, "Critical urgency indicators detected")
  end
  
  if factors.impact and factors.impact.level == "high" then
    table.insert(reasons, "High user/system impact expected")
  end
  
  if factors.security and factors.security.score > 3 then
    table.insert(reasons, "Security implications identified")
  end
  
  return table.concat(reasons, "; ")
end

M.generate_effort_reasoning = function(factors)
  local reasons = {}
  
  if factors.scope and factors.scope.level == "large" then
    table.insert(reasons, "Large scope indicated by keywords")
  end
  
  if factors.complexity and factors.complexity.level == "high" then
    table.insert(reasons, "High technical complexity expected")
  end
  
  if factors.dependencies and factors.dependencies > 3 then
    table.insert(reasons, "Multiple dependencies identified")
  end
  
  return table.concat(reasons, "; ")
end

-- Confidence calculation
M.calculate_priority_confidence = function(todo_data, context_data)
  local confidence = 50 -- Base confidence
  
  -- Text analysis confidence
  if todo_data.text and #todo_data.text > 20 then
    confidence = confidence + 10
  end
  
  -- Context data confidence
  if context_data and context_data.confidence_score then
    confidence = confidence + (context_data.confidence_score * 0.3)
  end
  
  -- Keyword matching confidence
  local keyword_matches = M.count_priority_keywords(todo_data.text)
  confidence = confidence + (keyword_matches * 5)
  
  return math.min(confidence, 100)
end

M.calculate_effort_confidence = function(todo_data, context_data)
  local confidence = 40 -- Lower base for effort estimation
  
  -- Scope indicators confidence
  local scope_indicators = M.count_scope_keywords(todo_data.text)
  confidence = confidence + (scope_indicators * 8)
  
  -- Code context confidence
  if context_data and context_data.code_analysis then
    confidence = confidence + 15
  end
  
  return math.min(confidence, 100)
end

M.calculate_overall_confidence = function(estimation)
  local priority_conf = estimation.confidence.priority or 50
  local effort_conf = estimation.confidence.effort or 50
  
  return (priority_conf + effort_conf) / 2
end

-- Helper functions for confidence calculation
M.count_priority_keywords = function(text)
  local priority_keywords = {
    "critical", "urgent", "important", "asap", "immediately",
    "security", "bug", "error", "broken", "failing"
  }
  
  local count = 0
  text = text:lower()
  
  for _, keyword in ipairs(priority_keywords) do
    if text:find(keyword) then
      count = count + 1
    end
  end
  
  return count
end

M.count_scope_keywords = function(text)
  local scope_keywords = {
    "rewrite", "refactor", "major", "complete", "system",
    "fix", "simple", "quick", "minor", "small"
  }
  
  local count = 0
  text = text:lower()
  
  for _, keyword in ipairs(scope_keywords) do
    if text:find(keyword) then
      count = count + 1
    end
  end
  
  return count
end

-- Integration with external systems
M.enhance_with_ai_estimation = function(todo_data, existing_context)
  -- Get enhanced context
  local enhanced_context = require('todo-mcp.ai.context').detect_enhanced_context(
    todo_data.file_path, 
    todo_data.text,
    todo_data.surrounding_lines
  )
  
  -- Combine with existing context
  local full_context = vim.tbl_extend("force", existing_context or {}, enhanced_context)
  
  -- Generate AI estimations
  local estimation = M.estimate_todo_metrics(todo_data, full_context)
  
  -- Update todo with AI insights
  local metadata = todo_data.metadata and vim.json.decode(todo_data.metadata) or {}
  metadata.ai_estimation = estimation
  metadata.ai_enhanced = true
  metadata.ai_timestamp = os.date("%Y-%m-%d %H:%M:%S")
  
  return {
    updated_metadata = vim.json.encode(metadata),
    ai_priority = estimation.priority.level,
    estimated_effort = estimation.effort.level,
    confidence_score = estimation.confidence.overall
  }
end

return M