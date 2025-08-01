import { ILogger, ILoggerFactory } from "@js-soft/logging-abstractions";
import { ApplicationError, Result } from "@js-soft/ts-utils";
import { INotificationAccess, INotificationScheduleOptions } from "@nmshd/app-runtime";

export class NotificationAccess implements INotificationAccess {
  private logger: ILogger;

  public constructor(private readonly loggerFactory: ILoggerFactory) {}

  public async getPushToken(): Promise<Result<string>> {
    const result: { ok: true; token: string } | { ok: false; error: string } =
      await window.flutter_inappwebview.callHandler("notifications_getPushToken");
    if (!result.ok) {
      return Result.fail(new ApplicationError("error.app.gettingPushTokenFailed", result.error));
    }

    return Result.ok(result.token);
  }

  public init(): Promise<Result<void>> {
    this.logger = this.loggerFactory.getLogger("NotificationAccess");
    return Promise.resolve(Result.ok(undefined));
  }

  public async schedule(title: string, body: string, options?: INotificationScheduleOptions): Promise<Result<number>> {
    if (options?.textInput) this.logger.warn("Notification text input actions not supported on this platform");

    const id = options?.id ? options.id : Math.round(Math.random() * 1000);
    await window.flutter_inappwebview.callHandler("notifications_schedule", title, body, id);

    return Result.ok(id);
  }

  public async update(
    id: number,
    title: string,
    body: string,
    options?: INotificationScheduleOptions
  ): Promise<Result<void>> {
    await this.schedule(title, body, { ...options, id });
    return Result.ok(undefined);
  }

  public async clear(id: number): Promise<Result<void>> {
    await window.flutter_inappwebview.callHandler("notifications_clear", id);
    return Result.ok(undefined);
  }

  public async clearAll(): Promise<Result<void>> {
    await window.flutter_inappwebview.callHandler("notifications_clearAll");
    return Promise.resolve(Result.ok(undefined));
  }

  public async getAll(): Promise<Result<number[]>> {
    const notificationIds: number[] = await window.flutter_inappwebview.callHandler("notifications_getAll");
    return Result.ok(notificationIds);
  }
}
