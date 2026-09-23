using MauiApp3.Commands;
using MauiApp3.Data;
using MauiApp3.Queries;
using MauiApp3.ViewModel;
using Microsoft.Extensions.Logging;

namespace MauiApp3
{
    public static class MauiProgram
    {
        public static MauiApp CreateMauiApp()
        {
            var builder = MauiApp.CreateBuilder();
            builder
                .UseMauiApp<App>();
            builder.Services.AddSingleton<PlayerRepository>();
            builder.Services.AddTransient<AddPlayerCommandHandler>();
            builder.Services.AddTransient<GetPlayerByIdQueryHandler>();
            builder.Services.AddTransient<GetPlayersQueryHandler>();
            builder.Services.AddTransient<MainViewModel>();
            builder.Services.AddTransient<MainPage>();


#if DEBUG
            builder.Logging.AddDebug();
#endif

            return builder.Build();
        }
    }
}
