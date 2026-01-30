using System.Collections.Generic;
using System.Threading.Tasks;

namespace Playbook.Module.GovernedExample.Services
{
    public interface IGovernedExampleService 
    {
        Task<List<Models.GovernedExample>> GetGovernedExamplesAsync(int ModuleId);

        Task<Models.GovernedExample> GetGovernedExampleAsync(int GovernedExampleId, int ModuleId);

        Task<Models.GovernedExample> AddGovernedExampleAsync(Models.GovernedExample GovernedExample);

        Task<Models.GovernedExample> UpdateGovernedExampleAsync(Models.GovernedExample GovernedExample);

        Task DeleteGovernedExampleAsync(int GovernedExampleId, int ModuleId);
    }
}
