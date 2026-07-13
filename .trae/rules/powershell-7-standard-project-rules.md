---
alwaysApply: true
---
# PowerShell 7 专项开发规则

## 1. 语法与架构硬性约束

- **强类型契约**：禁止使用弱类型定义。必须为所有变量、函数参数（`param` 块）及返回值显式标注类型。
  - 示例：`[string]$UserName = "Lucas"`, `[int]$RetryCount = 3`
- **标准架构**：所有函数必须包含 `[CmdletBinding()]` 和 `[OutputType()]` 属性，并统一使用 `param()` 块定义参数。
  - `[OutputType()]` 示例：

    ```powershell
    function Get-Example {
        [CmdletBinding()]
        [OutputType([string])]
        param (
            [string]$InputParam
        )
        return "result"
    }
    ```

  - 对于返回布尔值的函数：`[OutputType([bool])]`
  - 对于无返回值或仅输出到管道的函数：`[OutputType([void])]`
  - 对于可能返回 `$null` 的函数：`[OutputType([nullable])]` 或 `[OutputType([object])]`

## 2. 命名与风格规范

- **PascalCase 强制化**：所有自定义变量名、函数名、参数名必须使用 PascalCase（大驼峰命名法）。
  - *例外情况*：系统内置自动变量（如 `$PSBoundParameters`, `$PSItem`, `$args`, `$foreach`, `$HOME` 等）保持原样，不强制执行。
- **$PSItem 强制化**：禁止使用 `$_`，必须使用`$PSItem` 以提高可读性。
  - 适用于所有场景：`ForEach-Object`、`Where-Object`、`switch` 语句、管道脚本块等。
- **重构指令**：在修改或重构现有代码时，AI 必须主动修复不符合 PascalCase 规范或缺失类型声明的旧代码块。

### 2.1 模块结构约定

本项目的模块源文件按以下目录结构组织：

```text
source/
├── Classes/       # PowerShell 类定义（每个类一个文件）
├── Public/        # 公开导出的函数
├── Private/       # 内部私有函数
├── FinalizeAndArchiveProject.psd1  # 模块清单
└── FinalizeAndArchiveProject.psm1  # 模块脚本（负责点来源文件和导出）
```

- **Public 函数**：必须声明 `[CmdletBinding()]`、`[OutputType()]` 和完整 Help 注释。
- **Private 函数**：同样需要 `[CmdletBinding()]` 和 `[OutputType()]`，Help 注释可适当精简，但至少包含 `.SYNOPSIS`。
- **Class 文件**：每个类单独一个文件，文件名与类名一致（PascalCase），并包含完整的类 Help 注释。

## 3. 防御性编程 (Error Handling)

- **风险驱动的 Try-Catch**：
  - 凡涉及 **IO 操作**（文件读取、写入、移动等）的逻辑，必须包裹在 `try-catch` 结构中。
  - 凡涉及 **网络请求**（如 `Invoke-RestMethod`, `Invoke-WebRequest`）的逻辑，必须包裹在 `try-catch` 结构中。
  - `catch` 块应包含明确的异常处理逻辑（如 `throw $PSItem`）。

## 4. 强制 Help-Based Help 模板

每个定义的函数上方必须包含以下格式的注释块，作者信息固定如下：

```powershell
<#
.SYNOPSIS
    [简要描述函数功能]
.DESCRIPTION
    [详细解释函数的工作原理、逻辑及适用场景]
.PARAMETER [参数名]
    (类型) [该参数的作用及说明]
.EXAMPLE
    [具体的用法示例]
.INPUTS
    [输入对象类型]
.OUTPUTS
    [输出对象类型]
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
```

### 4.1 PowerShell 类 Help-Based Help 规范

PowerShell 类及其成员也需要完整的 Help-Based Help 文档。

#### 4.1.1 类定义 Help

每个类定义上方必须包含以下格式的注释块：

```powershell
<#
.SYNOPSIS
    [简要描述类的功能]
.DESCRIPTION
    [详细解释类的作用、职责及设计意图]
.EXAMPLE
    [类的使用示例]
.NOTES
    Author:  lucas_gold
    Website: https://github.com/1274248407
#>
class ClassName
{
    # 属性定义...
}
```

#### 4.1.2 类属性 Help

每个类属性上方必须添加单行注释说明其用途：

```powershell
class ClassName
{
    # 属性的简要说明
    [string]$PropertyName

    # 另一个属性的简要说明
    [int]$AnotherProperty
}
```

#### 4.1.3 类方法 Help

每个类方法（包括构造函数、静态方法、实例方法）上方必须包含以下格式的注释块：

```powershell
class ClassName
{
    <#
    .SYNOPSIS
        [简要描述方法功能]
    .DESCRIPTION
        [详细解释方法的工作原理、参数及返回值]
    .PARAMETER [参数名]
        (类型) [该参数的作用及说明]
    .EXAMPLE
        [具体的方法调用示例]
    .OUTPUTS
        [输出对象类型]
    .NOTES
        Author:  lucas_gold
        Website: https://github.com/1274248407
    #>
    [ReturnType] MethodName([Type]$ParamName)
    {
        # 方法实现...
    }
}
```

## 5. 代码注释规范

- **简体中文强制**：所有代码注释（包括单行注释 `#` 和多行注释 `<#...#>`）必须使用简体中文。
  - 函数帮助块的所有内容（.SYNOPSIS、.DESCRIPTION、.PARAMETER 等）必须使用简体中文。
  - 代码中的解释性注释必须使用简体中文。
  - 变量、函数名、参数名等标识符保持英文不变。
- **单行注释强制要求**：以下代码结构前必须添加单行注释说明其用途：
  - 变量声明（尤其是复杂表达式或计算结果）
  - 条件判断（`if`、`switch`）
  - 循环结构（`for`、`foreach`、`while`、`do`）
  - 异常处理块（`try-catch`）
  - 示例：

    ```powershell
    # 构建输出文件路径
    $OutputPath = Join-Path $TmpDir 'output.txt'

    # 检查环境是否满足要求
    if (-not (Test-Path $PythonPath))
    {
        throw "Python 环境不存在"
    }

    # 遍历所有待处理文件
    foreach ($File in $Files)
    {
        # 处理单个文件
        Process-File -Path $File
    }
    ```

## 6. 测试框架规范（Pester v5）

### 6.0 版本要求

- **强制版本**：必须使用 **Pester v5** 版本（v5.3.0 及以上）。
- **版本声明**：测试文件开头应使用 `#Requires -Modules Pester` 声明依赖。
- **兼容性**：禁止使用 Pester v4 及更早版本的语法（如 `Should Be` 需改为 `Should -Be`）。

### 6.1 文件命名规范

- **测试文件命名**：测试文件必须以 `.Tests.ps1` 结尾。
- **文件路径结构**：测试文件应放置在项目根目录下的 `tests` 目录中：
  - 单元测试：`tests/Unit/*.Unit.Tests.ps1`
  - 集成测试：`tests/Integration/*.Integration.Tests.ps1`
  - 系统测试：`tests/System/*.System.Tests.ps1`
  - 验收测试：`tests/Acceptance/*.Acceptance.Tests.ps1`
- **命名模式**：
  - 单元测试/集成测试/验收测试：`{ModuleName}_{FunctionName}.{TestType}.Tests.ps1`
    - 示例：`FinalizeAndArchiveProject_Start-FinalizeAndArchive.Unit.Tests.ps1`
  - 系统测试：`{SystemName}.{TestType}.Tests.ps1`
    - 示例：`FinalizeAndArchive.Workflow.System.Tests.ps1`、`FinalizeAndArchive.FullPipeline.System.Tests.ps1`

### 6.2 测试结构规范

- **Describe 块**：用于组织相关测试，描述被测功能模块。
- **Context 块**：用于分组测试场景，描述特定条件下的行为。
- **It 块**：单个测试用例，描述具体的测试断言。
- **BeforeAll/AfterAll**：在所有测试前后执行，用于模块导入和清理。
- **BeforeEach/AfterEach**：在每个测试前后执行，用于测试隔离和清理。

### 6.3 测试分类规范

#### 6.3.1 单元测试（Unit Testing）

- **测试范围**：测试单个函数或方法的独立功能。
- **隔离要求**：完全隔离外部依赖，使用 Mock 替代。
- **目的**：验证函数的逻辑正确性，确保每个单元按预期工作。

#### 6.3.2 集成测试（Integration Testing）

- **测试范围**：测试多个模块或组件之间的交互。
- **依赖处理**：可以使用部分真实依赖，测试模块间的接口。
- **目的**：验证模块集成后的协同工作是否正常。

#### 6.3.3 系统测试（System Testing）

- **测试范围**：测试整个系统的端到端流程。
- **环境要求**：使用真实的测试环境和数据。
- **目的**：验证系统整体功能符合需求规格。

#### 6.3.4 验收测试（Acceptance Testing）

- **测试范围**：从用户角度验证系统功能。
- **测试依据**：基于用户需求和业务场景。
- **目的**：确保系统满足业务需求，可交付使用。

### 6.4 Mock 规范

- **优先使用 TestDrive**：对于文件操作测试，优先使用 Pester 的 `TestDrive` 功能进行真实文件操作，而非 Mock。
- **只 Mock 外部依赖**：仅 Mock 模块外部的依赖（如系统命令、外部服务调用），不 Mock 模块内部函数。
- **Mock 应在 BeforeEach 中定义**：每个测试前重新定义 Mock，避免测试间的状态污染。
- **避免过度 Mock**：不要为了测试而过度 Mock，保持测试的真实性和可靠性。
- **使用 -ModuleName 参数**：当需要 Mock 模块内调用的命令时，必须使用 `-ModuleName` 参数指定目标模块。

### 6.5 断言规范

- **使用精确断言**：断言应尽可能精确，避免模糊匹配导致的误报。
- **避免简单字符串匹配**：对于内容验证，应使用完整行格式匹配，而非单独的关键字或数字。
  - 不好：`$content | Should -Match '\[X\]'`
  - 好：`$content | Should -Match '- 原始文件是否需要高清化: \[X\]'`
- **使用适当的断言方法**：根据测试场景选择合适的断言方法（如 `-Be`, `-Match`, `-Exist` 等）。

### 6.6 测试隔离规范

- **使用 TestDrive**：文件操作测试必须使用 `TestDrive` 进行隔离，避免影响真实文件系统。
- **清理测试数据**：在 `AfterEach` 或 `AfterAll` 中清理测试产生的数据和状态。
- **避免共享状态**：测试之间不应共享状态，每个测试应独立运行。
